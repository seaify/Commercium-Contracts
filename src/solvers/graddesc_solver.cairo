%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.uint256 import Uint256

from src.lib.utils import Utils, Router, Path
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
    ) = IRouterAggregator.get_all_routers_and_reserves(_token_in, _token_out);

    // Pre-Calc
    let (pre_calcs: PreCalc*) = alloc(); 
    set_pre_calculations(pre_calcs,reserves_a,reserves_b,reserves_a_len);

    // Set starting weights
    let init_amount = unsigned_div_rem(_amount_in.low,routers_len);
    init_amounts(routers_len, amounts, init_amount);

    //Get initial out_amount
    let new_out_amount = objective_func(pre_calcs, routers_len, amounts, total_received_token_amount=0);

    //Run Gradient Descent
    let (final_amounts, amount_out) = gradient_descent(pre_calcs, _amount_in, new_out_amount, routers_len, amounts, STEP_SIZE, counter=0);

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
    pre_calcs: PreCalc*, input_amount: felt, out_amount: felt, amounts_len: felt, amounts: felt*, step_size: felt, counter: felt
) -> (amounts: felt*, final_out_amount: felt){
    
    //Max Iterations
    if (counter == 20){
        return(amounts,out_amount);
    }

    //Calculate gradients resulting from new amounts
    let (gradients: felt*) = alloc();
    gradient(
        pre_calcs=pre_calcs, 
        amounts_len=amounts_len, 
        amounts=amounts, 
        gradients=gradients, 
        counter=0
    );

    //Determine new trade amounts
    let inverseNorm = calc_inverse_norm(gradients);
    let delta_factor = Utils.felt_fmul(inverseNorm,step_size);
    let (new_amounts: felt*) = alloc();
    clac_new_amounts(delta_factor,amounts_len,amounts,gradients,new_amounts);

    //Check that single amounts are not > total_amount or < 0
    let (are_borders_crossed) = check_borders(amounts_len,new_amounts,input_amount,0);
    if (are_borders_crossed == TRUE) {
        return(amounts, out_amount);
    }

    //Calculate new output amounts resulting from new trade amounts
    let new_out_amount = objective_func(amounts_len=amounts_len, amounts=new_amounts, total_received_token_amount=0);

    //Check if new amount is more efficient
    let (is_new_amount_more) = is_le_felt(out_amount,new_out_amount);
    //If less efficient, redoo with last result and smaller stepsize
    if (new_out_amount == FALSE){
        //if stepsize_reductions == 0:
        return(amounts, out_amount);
        //end
    
        //let (new_stepsize,_) = unsigned_div_rem(stepsize,2)
        //let(xx, yy, amountOutt) = findWeights(x,y,0,arr,new_stepsize,stepsize_reductions-1,amountOut,counter+1,amountToBuy)
        //return(xx, yy, amountOutt);
    }else{
	    let(final_amounts, final_out_amount) = gradient_descent(pre_calcs, input_amount, new_out_amount);
    	return(final_amounts, final_out_amount);
    }
}

func objective_func{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pre_calcs: PreCalc*, amounts_len: felt, amounts: felt*, total_received_token_amount: felt
) -> felt {
    
    if (amounts_len == 0) {
        return(total_received_token_amount);
    }

    let received_token_amount = get_amount_out(pre_calcs[0], amounts[0], 0);

    let final_received_token_amount = objective_func(
        pre_calcs=pre_calcs + 1,
        amounts_len=amounts_len - 1, 
        amounts=amounts + 1, 
        total_received_token_amount=total_received_token_amount + received_token_amount
    );

    return(final_received_token_amount);
}

func get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pre_calcs: PreCalc, _amount_in: felt, router_type: felt 
) -> felt {

    //ToDo Check what can be pre-computed (e.g. reserve_1 * 1000)
    if (router_type == 0){
        let numerator = _amount_in * pre_calcs.feed_reserves_2;
        let denominator = pre_calcs.feed_reserves_1 + (_amount_in * 997);
        let amount_out = unsigned_div_rem(numerator, denominator);
        return (amount_out);
    }

    with_attr error_message("GRADDESC: Router type isn't covered") {
        assert 1 = 2;
    }
    return(0);
}

func gradient{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pre_calcs: PreCalc*, amounts_len: felt, amounts: felt*, gradients: felt*, counter: felt
){
    if(counter == amounts_len){
        return();
    }

    assert gradients[0] = gradient_x(pre_calcs[0],amounts_len,amounts,counter);

    gradient(pre_calcs+1,amounts_len,amounts,gradients+1,counter+1);

    return(); 
}

func gradient_x{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pre_calc: PreCalc, amounts_len: felt, amounts: felt*, router_index: felt
) -> felt{

    //                 998998                           998998
    // _ ________________________________ +    ________________________
    //    (997*x + 997*y + 997*z -1998)^2          (997*x + 1001)^2

    let denominator_1 = calc_denominator(amounts_len, amounts, 0);

    let (gradient_part_1,_) = unsigned_div_rem(pre_calc.gradient_nominator,denominator_1);

    let denominator_2 = Utils.pow2(997*amounts[router_index] + pre_calc.feed_reserves_1);

    let (gradient_part_2,_) = unsigned_div_rem(pre_calc.gradient_nominator,denominator_2);
    
    let gradient = gradient_part_2 - gradient_part_1;

    return(gradient);
}

func set_pre_calculations{range_check_ptr}(
    pre_calcs: PreCalc*,reserves_1: Uint256*,reserves_2: Uint256*,reserves_len: felt
    ){

    if(reserves_len == 0){
        return();
    }

    let feed_reserves_1 = 1000 * reserves_1[0].low;
    let feed_reserves_2 = 997*reserves_2[0].low;

    assert pre_calcs[0] = PreCalc(feed_reserves_1,feed_reserves_2,feed_reserves_1*feed_reserves_2);

    set_pre_calculations(pre_calcs + 3,reserves_1 + 1,reserves_2 + 1,reserves_len - 1);
    return();
}

func shares_to_amounts{range_check_ptr}(
    shares_len: felt, shares: felt*, amounts: felt*, input_amount: felt
    ){

    if(shares_len == 0){
        return();
    }

    assert amounts[0] = Utils.felt_fmul(shares[0],input_amount);

    shares_to_amounts(shares_len-1, shares + 1, amounts, input_amount);

    return();
}

func init_amounts{}(
    amounts_len: felt, amounts: felt*, init_amount: felt
){
    if(amounts_len == 0){
        return();
    }

    assert amounts[0] = init_amount;

    init_amounts(amounts_len-1,amounts + 1,_amount_in);
}

func calc_denominator{}(amounts_len: felt, amounts: felt, sum: felt) -> felt{
    if (amounts_len == 0){
        let (restult) = Utils.pow2(sum - 1998);
        return(result);
    }

    let feed_amount = amounts[0]*997;
    return(calc_denominator(amounts_len-1,amounts+1,sum+feed_amount));
}

func clac_new_amounts{}(delta_factor: felt, gradients_len: felt, gradients: felt*, amounts: felt, new_amounts: felt*) -> felt{

    let (new_gradients: felt*) = alloc();
    fmul_array(gradients_len,gradients,new_gradients,delta_factor,BASE);

    add_two_arrays(gradients_len,new_gradients,new_amounts);

    return();
}

func calc_inverse_norm{}(gradients_len: felt, gradients: felt*) -> felt{

    let (new_gradients: felt*) = alloc();
    pow_gradients(gradients_len,new_gradients);

    let sum = sum_gradients(gradients_len,new_gradients);

    let norm = sqrt(sum);
    
    let inverseNorm = felt_fdiv(BASE,norm);

    return(inverseNorm);
}

func check_borders{}(
    amounts_len: felt, amounts: felt*, input_amount : felt, check_value: felt
) -> felt{
    if(amounts_len == 0){
        return();
    }

    let new_check_value = check_value + is_le_felt(input_amount,amounts[0]);

    return(check_borders(amounts_len -1, amounts + 1, input_amount, new_check_value));
}

// Multiplies every array element by a given factor
func fmul_array{}(
    array_len: felt, array: felt*, new_array: felt*, mul_factor: felt, base: felt
){
    if(array_len == 0){
        return();
    }

    assert new_array[0] = Utils.felt_fmul(array[0],mul_factor,base);

    mul_array(array_len - 1, array + 1, new_array + 1, mul_factor, base);

    return();
}

func add_two_arrays{}(
    array_len: felt, array: felt*, add_array: felt*, new_array: felt*
){
    if(array_len == 0){
        return();
    }

    assert new_array[0] = array[0] + add_array[0];

    mul_array(array_len - 1, array + 1, add_array + 1, new_array + 1);

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