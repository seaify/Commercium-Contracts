%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_le, uint256_unsigned_div_rem
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le_felt

from src.interfaces.i_router_aggregator import IRouterAggregator
from src.lib.utils import Router, Path, Utils
from src.lib.constants import BASE

// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                             //
//                      Very simple algorithm that divides trades among different exchanges according                          //
//           to a certain heuristic. This version is adapted to the testnet environment, where prices are very differnt        //
//           from exchange to exchange. This should eventually be replaced with something like gradient decent (if viable).    //
//                                                                                                                             //
// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

const THRESHOLD = 5000000000000000;  // 5e15 / 0.5%

@storage_var
func router_aggregator() -> (router_aggregator_address: felt) {
}

// ///////////////////////////
//       Constructor       //
// ///////////////////////////

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

    // Allocate arrs
    let (amounts: felt*) = alloc();
    let (below_average_routers: Router*) = alloc();
    let (below_average_amounts_out: Uint256*) = alloc();
    let (smaller_selection_amounts_out: Uint256*) = alloc();
    let (final_routers: Router*) = alloc();
    let (final_amounts_out: Uint256*) = alloc();
    let (path: Path*) = alloc();
    let (amounts_out: Uint256*) = alloc();

    // Get reserves of all exchanges
    let (router_aggregator_address) = router_aggregator.read();
    let (
        reserves_a_len: felt,
        reserves_a: Uint256*,
        reserves_b_len: felt,
        reserves_b: Uint256*,
        routers_len: felt,
        routers: Router*,
    ) = IRouterAggregator.get_all_routers_and_reserves(
        router_aggregator_address, _token_in, _token_out
    );

    // Keep above average liquid exchanges
    let (average: Uint256) = average_amounts(reserves_a_len, reserves_a);
    let (below_average_routers_len: felt) = kick_below_average(
        average, routers_len, below_average_routers, routers, below_average_amounts_out, amounts_out, routers_len
    );

    // Get amounts out
    IRouterAggregator.get_amount_from_provided_routers(
        router_aggregator_address,
        below_average_routers_len,
        below_average_routers,
        _token_in,
        _token_out,
        _amount_in,
        below_average_routers_len,
        smaller_selection_amounts_out,
    );

    // Keep exchanges whose price does not deviate to strongly from the best one
    let highest_val: Uint256 = highest_amount(below_average_routers_len, smaller_selection_amounts_out, Uint256(0,0));
    let (final_routers_len: felt) = kick_below_threshold(
        highest_val,
        below_average_routers_len,
        final_routers,
        routers,
        final_amounts_out,
        smaller_selection_amounts_out,
        below_average_routers_len,
    );

    // Divide trade amount among remaining DEXes and estimate amount
    let (final_sum: Uint256) = sum_amounts(final_routers_len, final_amounts_out);
    set_amounts(final_sum.low, final_routers_len, final_amounts_out, amounts);
    set_path(final_routers_len, path, _token_in, _token_out);

    return (
        routers_len=final_routers_len,
        routers=final_routers,
        path_len=final_routers_len,
        path=path,
        amounts_len=final_routers_len,
        amounts=amounts,
    );
}

// ///////////////////////////
//         Internals        //
// ///////////////////////////

func sum_amounts{range_check_ptr}(_amounts_len: felt, _amounts: Uint256*) -> (sum: Uint256) {
    if (_amounts_len == 0) {
        return (Uint256(0, 0),);
    }

    let (sum: Uint256) = sum_amounts(_amounts_len - 1, _amounts + 2);
    let (addition: Uint256, _) = uint256_add(_amounts[0], sum);
    return (addition,);
}

func average_amounts{range_check_ptr}(_amounts_len: felt, _amounts: Uint256*) -> (sum: Uint256) {
    let (sum: Uint256) = sum_amounts(_amounts_len, _amounts);
    let (average, _) = uint256_unsigned_div_rem(sum, Uint256(_amounts_len, 0));
    return (average,);
}

func highest_amount{range_check_ptr}(
    _amounts_len: felt, _amounts: Uint256*, _highest_amount: Uint256
) -> Uint256 {
    if (_amounts_len == 0) {
        return (_highest_amount);
    }

    let (is_le) = uint256_le(_highest_amount, _amounts[0]);

    if (is_le == TRUE) {
        let final_amount = highest_amount(_amounts_len - 1, _amounts + 2, _amounts[0]);
        return (final_amount);
    } else {
        let final_amount = highest_amount(_amounts_len - 1, _amounts + 2, _highest_amount);
        return (final_amount);
    }
}

func kick_below_average{range_check_ptr}(
    _average: Uint256,
    _routers_len: felt,
    _final_routers: Router*,
    _routers: Router*,
    _final_amounts_out: Uint256*,
    _amounts_out: Uint256*,
    _counter: felt,
) -> (_routers_len: felt) {
    alloc_locals;

    if (_counter == 0) {
        return (_routers_len,);
    }

    let (is_le) = uint256_le(_average, _amounts_out[0]);

    // If TRUE, kick router
    if (is_le == TRUE) {
        let (res_router_len) = kick_below_average(
            _average,
            _routers_len - 1,
            _final_routers,
            _routers + 2,
            _final_amounts_out,
            _amounts_out + 2,
            _counter - 1,
        );
        return (res_router_len,);
    } else {
        assert _final_routers[0] = _routers[0];
        assert _final_amounts_out[0] = _amounts_out[0];
        let (res_router_len) = kick_below_average(
            _average,
            _routers_len,
            _final_routers + 2,
            _routers + 2,
            _final_amounts_out + 2,
            _amounts_out + 2,
            _counter - 1,
        );
        return (res_router_len,);
    }
}

func kick_below_threshold{range_check_ptr}(
    _highest_val: Uint256,
    _routers_len: felt,
    _final_routers: Router*,
    _routers: Router*,
    _final_amounts_out: Uint256*,
    _amounts_out: Uint256*,
    _counter: felt,
) -> (_routers_len: felt) {
    alloc_locals;

    if (_counter == 0) {
        return (_routers_len,);
    }

    // Determine if router return amount deviates by more the THRESHOLD%
    let (difference) = uint256_sub(_highest_val, _amounts_out[0]);
    let (deviance) = Utils.fdiv(difference, _highest_val, Uint256(BASE,0));
    let is_le = is_le_felt(THRESHOLD, deviance.low);

    // If TRUE, kick router
    if (is_le == TRUE) {
        let (res_router_len) = kick_below_threshold(
            _highest_val,
            _routers_len - 1,
            _final_routers,
            _routers + 2,
            _final_amounts_out,
            _amounts_out + 2,
            _counter - 1,
        );
        return (res_router_len,);
    } else {
        assert _final_routers[0] = _routers[0];
        assert _final_amounts_out[0] = _amounts_out[0];
        let (res_router_len) = kick_below_threshold(
            _highest_val,
            _routers_len,
            _final_routers + 2,
            _routers + 2,
            _final_amounts_out + 2,
            _amounts_out + 2,
            _counter - 1,
        );
        return (res_router_len,);
    }
}

func set_amounts{range_check_ptr}(
    _sum: felt, _routers_len: felt, _amounts_out: Uint256*, _amounts: felt*
) {
    alloc_locals;

    if (_routers_len == 0) {
        return ();
    }

    local based_amounts_out = _amounts_out[0].low * BASE;
    let (local share, _) = unsigned_div_rem(based_amounts_out, _sum);
    assert _amounts[0] = share;

    // TODO: ADD SAFE MATH CHECK
    tempvar new_sum = _sum - _amounts_out[0].low;

    set_amounts(new_sum, _routers_len - 1, _amounts_out + 2, _amounts + 1);
    return ();
}

func set_path{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    path_len: felt, path: Path*, token_in: felt, token_out: felt
) {
    if (path_len == 0) {
        return ();
    }

    assert path[0] = Path(token_in, token_out);

    set_path(path_len - 1, path + 2, token_in, token_out);
    return ();
}
