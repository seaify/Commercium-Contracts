%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.interfaces.IERC20 import IERC20
from src.lib.utils import Router, Path
from src.lib.constants import BASE

//##################################################################################
//                                                                                 #
//   THIS IS THE SIMPLEST AND MOST FLEXIBLE SOLVER FOR INTEGRATION WITH PROTOCOLS  #
//                                                                                 #
//##################################################################################

// This should be a const, but easier like this for testing
@storage_var
func router_aggregator() -> (router_aggregator_address: felt) {
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

    let (router_aggregator_address) = router_aggregator.read();

    let (_, router: Router) = IRouter_aggregator.get_single_best_router(
        router_aggregator_address, _amount_in, _token_in, _token_out
    );

    let (routers: Router*) = alloc();
    let (path: Path*) = alloc();
    let (amounts: felt*) = alloc();

    assert routers[0] = router;
    assert path[0] = Path(_token_in, _token_out);
    assert amounts[0] = BASE;

    return (1, routers, 1, path, 1, amounts);
}

//
// Admin
//

@external
func set_router_aggregator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _router_aggregator: felt
) {
    router_aggregator.write(_router_aggregator);
    return ();
}
