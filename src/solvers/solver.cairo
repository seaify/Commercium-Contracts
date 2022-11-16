// SPDX-License-Identifier: MIT
// @author FreshPizza
%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from src.lib.utils import Router, Path

//////////////////////////////////////////////////////////////
//                                                          //
//   Base template for creating Commercium conform solvers  //
//                                                          // 
//////////////////////////////////////////////////////////////

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

// @notice Find the optimal trading path using the implemented algorithm
// @param _amount_in - Number of tokens to be sold
// @param _token_in - Address of the token to be sold
// @param _token_out - Address of the token to be bougth
// @return routers - Array of routers that are used in the trading path
// @return path - Array of token pairs that are used in the trading path
// @return amounts - Array of token amount that are used in the trading path
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
    let (path: Path*) = alloc();
    let (amounts: felt*) = alloc();

    return (1, routers, 1, path, 1, amounts);
}
