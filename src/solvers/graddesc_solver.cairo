%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem, sqrt
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import Uint256

from src.lib.utils import Utils, Router, Path
from src.lib.constants import BASE
from src.interfaces.i_router_aggregator import IRouterAggregator


const MAX_ITTERATIONS = 12;
const STEP_SIZE = 50000000000000000;  // 0.1
const MAX_STEP_REDUCTION = 3;
const STEP_DECREASE_FACTOR = 5;
const KICK_THRESHOLD = 80000000000000000; // 8%

struct PreCalc {
    feed_reserve: felt,  // fee * reserve_out
    based_reserve: felt,  // fee_base * reserve_in
    gradient_nominator: felt,  // feed_reserve * based_reserve
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
    routers_len: felt,
    routers: Router*,
    path_len: felt,
    path: Path*,
    amounts_len: felt,
    amounts: felt*,
) {
    alloc_locals;

    let (routers: Router*) = alloc();
    let (amounts: felt*) = alloc();

    let (router_aggregator_address) = router_aggregator.read();
    
    // Calculate minimum amount at which it is still viable to perform a trade at a DEX
    let KICK_AMOUNT = Utils.felt_fmul(_amount_in.low,KICK_THRESHOLD,BASE);

    let (
        reserves_a_len: felt,
        reserves_a: Uint256*,
        reserves_b_len: felt,
        reserves_b: Uint256*,
        local routers_len: felt,
        routers: Router*,
    ) = IRouterAggregator.get_all_routers_and_reserves(
        router_aggregator_address, _token_in, _token_out
    );
    local tester = reserves_a[0].low;
    //%{ print("Reserve 1 Amount InToken: ", ids.tester) %}
    local tester1 = reserves_b[0].low;
    //%{ print("Reserve 1 Amount OutToken: ", ids.tester1) %}
    
    local tester2 = reserves_a[1].low;
    //%{ print("Reserve 2 Amount InToken: ", ids.tester2) %}
    local tester3 = reserves_b[1].low;
    //%{ print("Reserve 2 Amount OutToken: ", ids.tester3) %}


    // Pre-Calc
    let (pre_calcs: PreCalc*) = alloc();
    set_pre_calculations(pre_calcs, reserves_a, reserves_b, reserves_a_len);

    let last_pre_calc = pre_calcs[reserves_a_len-1];

    // Set starting weights
    let (init_amount, _) = unsigned_div_rem(_amount_in.low, routers_len);
    init_amounts(routers_len, amounts, init_amount);

    // Get initial out_amount
    let new_out_amount = objective_func(
        pre_calcs, routers_len, amounts, _total_received_token_amount=0
    );

    // Run Gradient Descent
    let (final_amounts, amount_out) = gradient_descent(
        pre_calcs, _amount_in.low, new_out_amount, routers_len, amounts, STEP_SIZE, MAX_STEP_REDUCTION,_counter=0,_KICK_AMOUNT=KICK_AMOUNT,_last_pre_calc=last_pre_calc
    );

    // Kick 0 amounts, calc sum and build output values
    let (kicked_amounts: felt*) = alloc();
    let (kicked_routers: Router*) = alloc();
    let (path: Path*) = alloc();
    // Needed for amounts to shares transformation
    let (kicked_len,amounts_sum) = kick_zeros_and_build_output(
        _amounts_len=routers_len,
        _amounts=final_amounts,
        _routers=routers,
        _kicked_routers=kicked_routers,
        _kicked_amounts=kicked_amounts,
        _path=path,
        _token_in=_token_in,
        _token_out=_token_out,
        _amounts_sum=0,
        _counter=0
    );

    // Transform amounts to shares
    let (shares: felt*) = alloc();
    amounts_to_shares(
        _shares_len=kicked_len, 
        _shares=shares, 
        _amounts=kicked_amounts, 
        _sum=amounts_sum
    );

    return (
        kicked_len,
        kicked_routers,
        kicked_len,
        path,
        kicked_len,
        shares
    );
}

// ////////////////////////
//       Internal        //
// ////////////////////////

func gradient_descent{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pre_calcs: PreCalc*,
    _input_amount: felt,
    _out_amount: felt,
    _amounts_len: felt,
    _amounts: felt*,
    _step_size: felt,
    _decrease_step_counter: felt,
    _counter: felt,
    _KICK_AMOUNT: felt,
    _last_pre_calc: PreCalc
) -> (_amounts: felt*, final_out_amount: felt) {
    alloc_locals;

    // Max Iterations
    if (_counter == MAX_ITTERATIONS) {
        return (_amounts, _out_amount);
    }

    // Calculate gradients resulting from new amounts
    // symbols is either + or -
    // + = TRUE
    // - = FALSE
    let (local gradients: felt*) = alloc();
    let (local symbols: felt*) = alloc();
    gradient(
        _pre_calcs=_pre_calcs,
        _amounts_len=_amounts_len,
        _amounts=_amounts,
        _gradients=gradients,
        _symbols=symbols,
        _counter=0,
        _last_pre_calc=_last_pre_calc
    );

    //%{ print("After Gradient") %}

    // Determine new trade amounts
    let inverse_norm = calc_inverse_norm(_input_amount,_amounts_len-1, gradients);
    let (local new_amounts: felt*) = alloc();
    calc_new_amounts(gradients, symbols, inverse_norm, _amounts_len, _amounts, new_amounts, _input_amount, _KICK_AMOUNT, _step_size);
    //%{ print("After calc new amounts") %}

    // Determine last router amount
    let last_amount_value = missing_weight(_input_amount,_amounts_len,new_amounts);
    assert new_amounts[_amounts_len - 1] = last_amount_value;
    let weight1 = new_amounts[0];
    let weight2 = new_amounts[1];

    // Calculate new output amounts resulting from new trade amounts
    let new_out_amount = objective_func(
        _pre_calcs=_pre_calcs,
        _amounts_len=_amounts_len,
        _amounts=new_amounts,
        _total_received_token_amount=0,
    );

    // Check if new amount is more efficient
    let is_new_amount_more = is_le(_out_amount, new_out_amount);
    // If less efficient, redoo with last result and smaller stepsize
    if (is_new_amount_more == FALSE) {
        if (_decrease_step_counter != 0) {
            let (new_step_size,_) = unsigned_div_rem(_step_size,STEP_DECREASE_FACTOR);
            let (final_amounts, final_out_amount) = gradient_descent(
                _pre_calcs,
                _input_amount,
                _out_amount,
                _amounts_len,
                _amounts,
                new_step_size,
                _decrease_step_counter - 1,
                _counter + 1,
                _KICK_AMOUNT,
                _last_pre_calc,
            );
            return (final_amounts, final_out_amount);
        }else{
            return (_amounts, _out_amount);
        }
    // If more efficient, continue with new amounts
    } else {
        let (final_amounts, final_out_amount) = gradient_descent(
            _pre_calcs,
            _input_amount,
            new_out_amount,
            _amounts_len,
            new_amounts,
            _step_size,
            _decrease_step_counter,
            _counter + 1,
            _KICK_AMOUNT,
            _last_pre_calc,
        );
        return (final_amounts, final_out_amount);
    }
}

func objective_func{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pre_calcs: PreCalc*, _amounts_len: felt, _amounts: felt*, _total_received_token_amount: felt
) -> felt {
    if (_amounts_len == 0) {
        return (_total_received_token_amount);
    }

    let received_token_amount = get_amount_out(_pre_calcs[0], _amounts[0], 0);

    let final_received_token_amount = objective_func(
        _pre_calcs=_pre_calcs + 3,
        _amounts_len=_amounts_len - 1,
        _amounts=_amounts + 1,
        _total_received_token_amount=_total_received_token_amount + received_token_amount,
    );

    return (final_received_token_amount);
}

func get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pre_calcs: PreCalc, _amount_in: felt, _router_type: felt
) -> felt {
    alloc_locals;
    local tester1 = _pre_calcs.feed_reserve;
    local tester2 = _pre_calcs.based_reserve;

    // ToDo Check what can be pre-computed (e.g. reserve_1 * 1000)
    if (_router_type == 0) {
        let numerator = _amount_in * _pre_calcs.feed_reserve;
        let denominator = _pre_calcs.based_reserve + (_amount_in * 997);
        let (amount_out, _) = unsigned_div_rem(numerator, denominator);
        return (amount_out);
    }

    with_attr error_message("GRADDESC: Router type isn't covered") {
        assert 1 = 2;
    }
    return (0);
}

func gradient{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pre_calcs: PreCalc*, _amounts_len: felt, _amounts: felt*, _gradients: felt*, _symbols: felt*, _counter: felt, _last_pre_calc: PreCalc
) {
    if (_counter == _amounts_len-1) {
        return ();
    }

    let sum = sum_amounts_and_fees(_amounts_len, _amounts, 0);
    //%{ print("Sum: ", ids.sum) %}

    let (new_gradient: felt, symbol: felt) = gradient_x(
        _pre_calc_x=_pre_calcs[0], 
        _pre_calc_last=_last_pre_calc, 
        _amounts_len=_amounts_len, 
        _amounts=_amounts, 
        _router_index=_counter,
        _sum=sum,
    );
    assert _gradients[0] = new_gradient;
    assert _symbols[0] = symbol;

    gradient(_pre_calcs + 3, _amounts_len, _amounts, _gradients + 1, _symbols + 1, _counter + 1, _last_pre_calc);

    return ();
}

func missing_weight{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _sub_amount: felt, _new_amounts_len: felt, _new_amounts: felt*
) -> felt {
    if (_new_amounts_len == 1)  {
        return _sub_amount;
    }
    let sub_amount = _sub_amount - _new_amounts[0];
    return missing_weight(sub_amount, _new_amounts_len - 1, _new_amounts + 1);
}

func gradient_x{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pre_calc_x: PreCalc, _pre_calc_last: PreCalc,_amounts_len: felt, _amounts: felt*, _router_index: felt, _sum: felt
) -> (gradient: felt,negative: felt) {
    alloc_locals;

    //     based_reserveX * feed_reserveX                    based_reserveLAST * feed_reserveLAST
    // ___________________________________   _   ______________________________________________________________
    //     (Xfee*x + based_reserveX)^2            (feeLAST + based_reserveLAST - (Xfee*x + Yfee*y + Zfee*z))^2


    //%{ print("_pre_calc_last.based_reserve: ", ids._pre_calc_last.based_reserve) %}
    //%{ print("_pre_calc_last.gradient_nominator: ", ids._pre_calc_last.gradient_nominator) %}
    //%{ print("_pre_calc_x.based_reserve: ", ids._pre_calc_x.based_reserve) %}
    //%{ print("_pre_calc_x.gradient_nominator: ", ids._pre_calc_x.gradient_nominator) %}

    // Right Side 
    let (denominator_right) = pow(997 + _pre_calc_last.based_reserve + _sum,2);
    //%{ print("_sum", ids._sum) %}
    local tester = denominator_right;
    //%{ print("powed denominator_right", ids.tester) %}
    let (local division: felt,_) = unsigned_div_rem(denominator_right,BASE);
    //%{ print("Division", ids.division) %}
    let (local division2: felt,_) = unsigned_div_rem(_pre_calc_last.gradient_nominator,BASE);
    //%{ print("Division2", ids.division2) %}
    local gradient_right = Utils.felt_fdiv(division2, division, BASE);
    //%{ print("gradient_right", ids.gradient_right) %}

    //%{ print("Calculated right side") %}

    // Left Side
    let (denominator_2) = pow(997 * _amounts[_router_index] + _pre_calc_x.based_reserve, 2);
    local amount2 = _amounts[_router_index];
    //%{ print("_amounts[_router_index]: ", ids.amount2) %}
    let (local division3: felt,_) = unsigned_div_rem(denominator_2,BASE);
    //%{ print("Division3", ids.division3) %}
    let (local division4: felt,_) = unsigned_div_rem(_pre_calc_x.gradient_nominator,BASE);
    //%{ print("Division4", ids.division4) %}
    local gradient_left = Utils.felt_fdiv(division4, division3, BASE);


    //%{ print("--------------") %}
    //%{ print("gradient_left", ids.gradient_left) %}
    //%{ print("gradient_right", ids.gradient_right) %}

    // Preventing underflows, whilst continuing to use uint instead of int
    let is_right_side_smaller = is_le(gradient_right,gradient_left);
    if (is_right_side_smaller == TRUE) {
        return (gradient_left - gradient_right,TRUE);
    }else{
        return (gradient_right - gradient_left,FALSE);
    }
}

func set_pre_calculations{range_check_ptr}(
    _pre_calcs: PreCalc*, _reserves_1: Uint256*, _reserves_2: Uint256*, _reserves_len: felt
) {
    alloc_locals;
    if (_reserves_len == 0) {
        return ();
    }

    tempvar feed_reserve = 997 * _reserves_2[0].low;
    tempvar based_reserve = 1000 * _reserves_1[0].low;

    assert _pre_calcs[0] = PreCalc(feed_reserve, based_reserve, feed_reserve * based_reserve);

    set_pre_calculations(_pre_calcs + 3, _reserves_1 + 2, _reserves_2 + 2, _reserves_len - 1);
    return ();
}

func kick_zeros_and_build_output{range_check_ptr}(
    _amounts_len: felt, 
    _amounts: felt*, 
    _routers: Router*, 
    _kicked_routers: Router*, 
    _kicked_amounts: felt*, 
    _path: Path*, 
    _token_in: felt, 
    _token_out: felt, 
    _amounts_sum: felt, 
    _counter: felt
) -> (kicked_len: felt, amounts_sum: felt) {
    if (_amounts_len == 0) {
        return(_counter, _amounts_sum);
    }

    if (_amounts[0] != 0) {
        assert _kicked_amounts[0] = _amounts[0];
        assert _kicked_routers[0] = _routers[0];
        assert _path[0] = Path(_token_in,_token_out);
        let (kicked_len, amounts_sum) = kick_zeros_and_build_output(_amounts_len - 1, _amounts+1, _routers+2, _kicked_routers+2, _kicked_amounts+1, _path+2, _token_in, _token_out,  _amounts_sum + _amounts[0], _counter + 1);
        return(kicked_len, amounts_sum);
    }else{
        let (kicked_len, amounts_sum) = kick_zeros_and_build_output(_amounts_len - 1, _amounts+1, _routers, _kicked_routers, _kicked_amounts, _path, _token_in, _token_out, _amounts_sum, _counter);
        return(kicked_len, amounts_sum);
    }
}

func amounts_to_shares{range_check_ptr}(
    _shares_len: felt, _shares: felt*, _amounts: felt*, _sum: felt
) {
    if (_shares_len == 0) {
        return ();
    }

    let share = Utils.felt_fmul(_amounts[0], _sum, BASE);
    assert _shares[0] = share;

    amounts_to_shares(_shares_len - 1, _shares + 1, _amounts + 1, _sum);

    return ();
}

func init_amounts{range_check_ptr}(_amounts_len: felt, _amounts: felt*, _init_amount: felt) {
    if (_amounts_len == 0) {
        return ();
    }

    assert _amounts[0] = _init_amount;

    init_amounts(_amounts_len - 1, _amounts + 1, _init_amount);

    return ();
}

func sum_amounts_and_fees{range_check_ptr}(_amounts_len: felt, _amounts: felt*, _sum: felt) -> felt {
    if (_amounts_len == 0) {
        return (_sum);
    }
    let feed_amount = _amounts[0] * 997;
    let sum = sum_amounts_and_fees(_amounts_len - 1, _amounts + 1, _sum + feed_amount);
    return (sum);
}

func calc_new_amounts{range_check_ptr}(
    _gradients: felt*, _symbols: felt*, _inverse_norm: felt, _amounts_len: felt, _amounts: felt*, _new_amounts: felt*, _input_amount: felt, _KICK_AMOUNT: felt, _step_size: felt
) {
    alloc_locals;

    // We skip the last one
    if (_amounts_len == 1) {
        return();
    }

    // Calc delta
    let new_gradient = Utils.felt_fmul(_inverse_norm, _gradients[0], BASE);
    let delta_factor = Utils.felt_fmul(new_gradient, _step_size, BASE);

    if (_symbols[0] == TRUE) {
        // Fix upper bound
        // Max possibel amount to be traded on one router is the input amount
        let is_input_amount_smaller = is_le(_input_amount,delta_factor + _amounts[0]);
        if (is_input_amount_smaller == TRUE){
            assert _new_amounts[0] = _input_amount;
            calc_new_amounts(_gradients + 1, _symbols + 1, _inverse_norm, _amounts_len - 1, _amounts + 1, _new_amounts + 1, _input_amount, _KICK_AMOUNT, _step_size);
            return ();
        }else{
            assert _new_amounts[0] = _amounts[0] + delta_factor;
            calc_new_amounts(_gradients + 1, _symbols + 1, _inverse_norm, _amounts_len - 1, _amounts + 1, _new_amounts + 1, _input_amount, _KICK_AMOUNT, _step_size);
            return ();
        }
    }else{
        // Fix lower bound to 0
        let is_new_amount_smaller = is_le(_amounts[0] - delta_factor,_KICK_AMOUNT);
        if (is_new_amount_smaller == TRUE) {
            assert _new_amounts[0] = 0;
            calc_new_amounts(_gradients + 1, _symbols + 1, _inverse_norm, _amounts_len - 1, _amounts + 1, _new_amounts + 1, _input_amount, _KICK_AMOUNT, _step_size);
            return ();
        }else{
            assert _new_amounts[0] = _amounts[0] - delta_factor;
            calc_new_amounts(_gradients + 1, _symbols + 1, _inverse_norm, _amounts_len - 1, _amounts + 1, _new_amounts + 1, _input_amount, _KICK_AMOUNT, _step_size);
            return ();
        }
    }
}

func calc_inverse_norm{range_check_ptr}(_input_amount: felt, _gradients_len: felt, _gradients: felt*) -> felt {
    alloc_locals;

    let (new_gradients: felt*) = alloc();

    //%{ print("Powing Gradients") %}
    pow_gradients(_gradients_len, _gradients, new_gradients);
    //%{ print("Summing Gradients") %}

    let sum = sum_gradients(_gradients_len, new_gradients, sum=0);
    //%{ print("SQRTing Gradients") %}
    // Likely a big number issue here
    let small_norm = sqrt(sum);
    //%{ print("small_norm: ", ids.small_norm) %}

    let norm = small_norm * 1000000000;
    //%{ print("norm: ", ids.norm) %}

    let inverseNorm = Utils.felt_fdiv(_input_amount, norm, BASE);
    //%{ print("inverseNorm Done") %}

    return (inverseNorm);
}

func pow_gradients{range_check_ptr}(gradients_len: felt, gradients: felt*, new_gradients: felt*) {
    if (gradients_len == 0) {
        return ();
    }
    let to_div = gradients[0];
    //%{ print("diving: ",ids.to_div) %}
    let (small_gradient,_) = unsigned_div_rem(gradients[0],1000000000);
    //%{ print("small_gradient: ",ids.small_gradient) %}
    let (powed_gradient) = pow(small_gradient, 2);
    //%{ print("powed_gradient: ",ids.powed_gradient) %}
    assert new_gradients[0] = powed_gradient;

    pow_gradients(gradients_len - 1, gradients + 1, new_gradients + 1);

    return ();
}

func sum_gradients{range_check_ptr}(gradients_len: felt, gradients: felt*, sum: felt) -> felt {
    if (gradients_len == 0) {
        return (sum);
    }

    let new_sum = sum + gradients[0];

    let final_sum = sum_gradients(gradients_len - 1, gradients + 1, new_sum);

    return (final_sum);
}

// Multiplies every array element by a given factor
func fmul_array{range_check_ptr}(
    array_len: felt, array: felt*, new_array: felt*, mul_factor: felt, base: felt
) {
    if (array_len == 0) {
        return ();
    }

    assert new_array[0] = Utils.felt_fmul(array[0], mul_factor, base);

    fmul_array(array_len - 1, array + 1, new_array + 1, mul_factor, base);

    return ();
}

func add_two_arrays{range_check_ptr}(
    array_len: felt, array: felt*, add_array: felt*, new_array: felt*
) {
    if (array_len == 0) {
        return ();
    }

    assert new_array[0] = array[0] + add_array[0];

    add_two_arrays(array_len - 1, array + 1, add_array + 1, new_array + 1);

    return ();
}

//      x*997*reserve_2
// _________________________
// reserve_1 * 1000 + x*997

// ((x*997)/(1000+x*997)) + ((y*997)/(1000+y*997)) + ((z*997)/(1000+z*997))

// ((x*997)/(1000+x*997)) + ((y*997)/(1000+y*997)) + (((1-x-y)*997)/(1000+(1-x-y)*997))

// ((x*998)/(1001+x*997)) + ((y*998)/(1001+y*997)) + ((z*998)/(1001+z*997)) + (((1-x-y-z)*998)/(1001+(1-x-y-z)*997))

//                998998                           998998
// _ ________________________________ +    ________________________
//   (1998 - 997*x + 997*y + 997*z)^2          (997*x + 1001)^2

//           based_reserve * feed_reserve                         based_reserve * feed_reserve
// _ ________________________________________________       +    ______________________________
//   (fee+based_reserve - (Xfee*x + Yfee*y + Zfee*z))^2            (Xfee*x + based_reserve)^2