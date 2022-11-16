%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem, sqrt
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.uint256 import Uint256

from src.lib.utils import Utils, Router, Path
from src.lib.constants import BASE
from src.interfaces.i_router_aggregator import IRouterAggregator

const STEP_SIZE = 100000000000000000; //0.1
const MAX_STEP_REDUCTION = 3;   

struct PreCalc {
    feed_reserves_1: felt, //fee_base * reserve_1  
    feed_reserves_2: felt, //fee * reserve_2
    gradient_nominator: felt, //  feed_reserves_1 * feed_reserves_2
}

@storage_var
func router_aggregator() -> (router_aggregator_address: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _router_aggregator: felt
) {
    router_aggregator.write(_router_aggregator);
    return ();
}

@view
func get_results{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _token_in: felt, _token_out: felt
) -> (
    final_amounts_len: felt, final_amounts: felt*, amount_out: felt
) {
    alloc_locals;

    let (routers: Router*) = alloc();
    let (path: Path*) = alloc();
    let (amounts: felt*) = alloc();

    let (router_aggregator_address) = router_aggregator.read();

    let (
        reserves_a_len: felt,
        reserves_a: Uint256*,
        reserves_b_len: felt,
        reserves_b: Uint256*,
        routers_len: felt,
        routers: Router*,
    ) = IRouterAggregator.get_all_routers_and_reserves(router_aggregator_address,_token_in, _token_out);

    // Pre-Calc
    let (pre_calcs: PreCalc*) = alloc(); 
    set_pre_calculations(pre_calcs,reserves_a,reserves_b,reserves_a_len);

    // Set starting weights
    let (init_amount,_) = unsigned_div_rem(_amount_in.low,routers_len);
    init_amounts(routers_len, amounts, init_amount);

    %{
        print("Initial starting weight/amount: ", ids.init_amount)
    %}

    //Get initial out_amount
    let new_out_amount = objective_func(pre_calcs, routers_len, amounts, _total_received_token_amount=0);

    %{
        print("Initial out_amount: ", ids.new_out_amount)
    %}

    //Run Gradient Descent
    let (final_amounts, amount_out) = gradient_descent(pre_calcs, _amount_in.low, new_out_amount, routers_len, amounts, STEP_SIZE, _counter=0);

    // Transform amounts to shares
    // (In same step kick any share that is below a certain threshold e.g. 10%)
    // amounts_to_shares(routers_len,shares,final_amounts,_amount_in);

    // From new legth -> greate new path and routers arr 

    //return (routers_len, routers, 1, path, routers_len, shares);
    return(routers_len, final_amounts, amount_out);
}

// ////////////////////////
//       Internal        //
// ////////////////////////

func gradient_descent{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pre_calcs: PreCalc*, _input_amount: felt, _out_amount: felt, _amounts_len: felt, _amounts: felt*, _step_size: felt, _counter: felt
) -> (_amounts: felt*, final_out_amount: felt){
    alloc_locals;

    //Max Iterations
    if (_counter == 20){
        return(_amounts,_out_amount);
    }

    //Calculate gradients resulting from new amounts
    let (local gradients: felt*) = alloc();
    gradient(
        _pre_calcs=_pre_calcs, 
        _amounts_len=_amounts_len, 
        _amounts=_amounts, 
        _gradients=gradients, 
        _counter=0
    );

    //Determine new trade amounts
    let inverseNorm = calc_inverse_norm(_amounts_len, gradients);
    let delta_factor = Utils.felt_fmul(inverseNorm,_step_size,BASE);
    let (local new_amounts: felt*) = alloc();
    clac_new_amounts(delta_factor,_amounts_len,_amounts,new_amounts);

    //Check that single amounts are not > total_amount or < 0
    let are_borders_crossed = check_borders(_amounts_len,new_amounts,_input_amount,0);
    if (are_borders_crossed == TRUE) {
        return(_amounts, _out_amount);
    }

    //Calculate new output amounts resulting from new trade amounts
    let new_out_amount = objective_func(_pre_calcs=_pre_calcs, _amounts_len=_amounts_len, _amounts=new_amounts, _total_received_token_amount=0);

    //Check if new amount is more efficient
    let is_new_amount_more = is_le_felt(_out_amount,new_out_amount);
    //If less efficient, redoo with last result and smaller stepsize
    if (new_out_amount == FALSE){
        //if stepsize_reductions == 0:
        return(_amounts, _out_amount);
        //end
    
        //let (new_stepsize,_) = unsigned_div_rem(stepsize,2)
        //let(xx, yy, amountOutt) = findWeights(x,y,0,arr,new_stepsize,stepsize_reductions-1,amountOut,counter+1,amountToBuy)
        //return(xx, yy, amountOutt);
    }else{
	    let(final_amounts, final_out_amount) = gradient_descent(_pre_calcs, _input_amount, new_out_amount, _amounts_len, new_amounts, _step_size, _counter+1);
    	return(final_amounts, final_out_amount);
    }
}

func objective_func{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pre_calcs: PreCalc*, _amounts_len: felt, _amounts: felt*, _total_received_token_amount: felt
) -> felt {
    
    if (_amounts_len == 0) {
        return(_total_received_token_amount);
    }

    let received_token_amount = get_amount_out(_pre_calcs[0], _amounts[0], 0);

    let final_received_token_amount = objective_func(
        _pre_calcs=_pre_calcs + 1,
        _amounts_len=_amounts_len - 1, 
        _amounts=_amounts + 1, 
        _total_received_token_amount=_total_received_token_amount + received_token_amount
    );

    return(final_received_token_amount);
}

func get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pre_calcs: PreCalc, _amount_in: felt, _router_type: felt 
) -> felt {

    //ToDo Check what can be pre-computed (e.g. reserve_1 * 1000)
    if (_router_type == 0){
        let numerator = _amount_in * _pre_calcs.feed_reserves_2;
        let denominator = _pre_calcs.feed_reserves_1 + (_amount_in * 997);
        let (amount_out,_) = unsigned_div_rem(numerator, denominator);
        return (amount_out);
    }

    with_attr error_message("GRADDESC: Router type isn't covered") {
        assert 1 = 2;
    }
    return(0);
}

func gradient{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pre_calcs: PreCalc*, _amounts_len: felt, _amounts: felt*, _gradients: felt*, _counter: felt
){
    if(_counter == _amounts_len){
        return();
    }

    let new_gradient = gradient_x(_pre_calcs[0],_amounts_len,_amounts,_counter);
    assert _gradients[0] = new_gradient;

    gradient(_pre_calcs+1,_amounts_len,_amounts,_gradients+1,_counter+1);

    return(); 
}

func gradient_x{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pre_calc: PreCalc, _amounts_len: felt, _amounts: felt*, _router_index: felt
) -> felt{

    //                 998998                           998998
    // _ ________________________________ +    ________________________
    //    (997*x + 997*y + 997*z -1998)^2          (997*x + 1001)^2

    let denominator_1 = calc_denominator(_amounts_len, _amounts, 0);

    let (gradient_part_1,_) = unsigned_div_rem(pre_calc.gradient_nominator,denominator_1);

    let denominator_2 = Utils.pow2(997*_amounts[_router_index] + pre_calc.feed_reserves_1);

    let (gradient_part_2,_) = unsigned_div_rem(pre_calc.gradient_nominator,denominator_2);
    
    let gradient = gradient_part_2 - gradient_part_1;

    return(gradient);
}

func set_pre_calculations{range_check_ptr}(
    _pre_calcs: PreCalc*,_reserves_1: Uint256*,_reserves_2: Uint256*,_reserves_len: felt
    ){

    if(_reserves_len == 0){
        return();
    }

    let feed_reserves_1 = 1000 * _reserves_1[0].low;
    let feed_reserves_2 = 997*_reserves_2[0].low;

    assert _pre_calcs[0] = PreCalc(feed_reserves_1,feed_reserves_2,feed_reserves_1*feed_reserves_2);

    set_pre_calculations(_pre_calcs + 3,_reserves_1 + 1,_reserves_2 + 1,_reserves_len - 1);
    return();
}

func shares_to_amounts{range_check_ptr}(
    _shares_len: felt, _shares: felt*, _amounts: felt*, _input_amount: felt
    ){

    if(_shares_len == 0){
        return();
    }

    let amount = Utils.felt_fmul(_shares[0],_input_amount,BASE);
    assert _amounts[0] = amount;

    shares_to_amounts(_shares_len-1, _shares + 1, _amounts, _input_amount);

    return();
}

func init_amounts{range_check_ptr}(
    _amounts_len: felt, _amounts: felt*, _init_amount: felt
){
    if(_amounts_len == 0){
        return();
    }

    assert _amounts[0] = _init_amount;

    init_amounts(_amounts_len-1,_amounts + 1,_init_amount);
    
    return();
}

func calc_denominator{range_check_ptr}(
    _amounts_len: felt, _amounts: felt*, _sum: felt
) -> felt{
    if (_amounts_len == 0){
        let result = Utils.pow2(_sum - 1998);
        return(result);
    }

    let feed_amount = _amounts[0]*997;
    let denominator = calc_denominator(_amounts_len-1,_amounts+1,_sum+feed_amount);
    return(denominator);
}

func clac_new_amounts{range_check_ptr}(
    _delta_factor: felt, _amounts_len: felt, _amounts: felt*, _new_amounts: felt*
){
    alloc_locals;
    let (local mul_amounts: felt*) = alloc();
    fmul_array(_amounts_len,_amounts,mul_amounts,_delta_factor,BASE);

    add_two_arrays(_amounts_len,_amounts,mul_amounts,_new_amounts);

    return();
}

func calc_inverse_norm{range_check_ptr}(
    _gradients_len: felt, _gradients: felt*
) -> felt{

    let (new_gradients: felt*) = alloc();
    pow_gradients(_gradients_len,_gradients,new_gradients);

    let sum = sum_gradients(_gradients_len,_gradients,sum=0);

    let norm = sqrt(sum);
    
    let inverseNorm = Utils.felt_fdiv(BASE,norm,BASE);

    return(inverseNorm);
}

func check_borders{range_check_ptr}(
    _amounts_len: felt, _amounts: felt*, _input_amount : felt, check_value: felt
) -> felt{
    if(_amounts_len == 0){
        return(FALSE);
    }

    //Only checking upward breach
    let is_border_breached_upward = is_le_felt(_input_amount,_amounts[0]);
    
    //Do something like this
    //let is_border_breached_downward = is_le_felt(amounts[0],0);

    if (is_border_breached_upward == TRUE){
        return(TRUE);
    }

    check_borders(_amounts_len -1, _amounts + 1, _input_amount, 0);

    return(FALSE);
}

func pow_gradients{range_check_ptr}(
    gradients_len: felt, gradients: felt*, new_gradients: felt*
){
    if(gradients_len == 0){
        return();
    }

    let powed_gradient = Utils.pow2(gradients[0]);
    assert new_gradients[0] = powed_gradient;

    pow_gradients(gradients_len - 1, gradients + 1, new_gradients + 1);

    return();
}

func sum_gradients{range_check_ptr}(
    gradients_len: felt, gradients: felt*, sum: felt
) -> felt {
    if(gradients_len == 0){
        return(sum);
    }

    let new_sum = sum + gradients[0];

    let final_sum = sum_gradients(gradients_len - 1, gradients + 1, new_sum);

    return(final_sum);
}


// Multiplies every array element by a given factor
func fmul_array{range_check_ptr}(
    array_len: felt, array: felt*, new_array: felt*, mul_factor: felt, base: felt
){
    if(array_len == 0){
        return();
    }

    assert new_array[0] = Utils.felt_fmul(array[0],mul_factor,base);

    fmul_array(array_len - 1, array + 1, new_array + 1, mul_factor, base);

    return();
}

func add_two_arrays{range_check_ptr}(
    array_len: felt, array: felt*, add_array: felt*, new_array: felt*
){
    if(array_len == 0){
        return();
    }

    assert new_array[0] = array[0] + add_array[0];

    add_two_arrays(array_len - 1, array + 1, add_array + 1, new_array + 1);

    return();
} 

//    x*997*reserve_2
//_________________________
//reserve_1 + 1000 + x*997


//((x*997)/(1000+x*997)) + ((y*997)/(1000+y*997)) + ((z*997)/(1000+z*997))

//((x*997)/(1000+x*997)) + ((y*997)/(1000+y*997)) + (((1-x-y)*997)/(1000+(1-x-y)*997))

//((x*998)/(1001+x*997)) + ((y*998)/(1001+y*997)) + ((z*998)/(1001+z*997)) + (((1-x-y-z)*998)/(1001+(1-x-y-z)*997))

//                998998                           998998
//_ ________________________________ +    ________________________
//   (997*x + 997*y + 997*z -1998)^2          (997*x + 1001)^2