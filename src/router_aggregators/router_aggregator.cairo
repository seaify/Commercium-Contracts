// SPDX-License-Identifier: MIT
// @author FreshPizza
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_sub
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le_felt

from openzeppelin.access.ownable.library import Ownable
from src.interfaces.i_empiric_oracle import IEmpiricOracle
from src.lib.utils import Utils, Router
from src.lib.constants import BASE, BASE_8
from src.lib.router_aggregator import (
    RouterAggregator,
    Feed,
    price_feed,
    routers,
    router_index_len,
    top_routers,
    top_router_index_len,
)

// ///////////////////////////////////////////////////////////////////////////////////////////
//                                                                                          //
//                  The implementation of the Router Aggregator Contract.                   //
//   Includes interfaces of all DEX routers. Allows for simple querying of amounts/reserves //
//             of said DEXes as well as some other utility functions for solvers.           //                                      //
//                                                                                          //
// ///////////////////////////////////////////////////////////////////////////////////////////

// //////////////////////
//       Views        //
// //////////////////////

// @notice Returns address of a price oracle for the provided token
// @param _token - address of the token that one wants the price feed of
// @return feed - The oracle address and Emperic price feed key belonging to the provided token-USD pair
@view
func get_price_feed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token: felt
) -> (feed: Feed) {
    let (feed: Feed) = price_feed.read(_token);
    return (feed,);
}

// @notice provided the router address and type for a given router ID
// @param _index - The ID of the router to fetch
// @return router_address - The address of the router contract
// @return router_type - The type of the returned router (see lib/constants)
@view
func get_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_index: felt) -> (
    router_address: felt, router_type: felt
) {
    let (router: Router) = routers.read(_index);

    return (router.address, router.type);
}

// @notice get the number of saved routers
// @return len - The number of registered routers
@view
func get_router_index_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    len: felt
) {
    let (len) = router_index_len.read();
    return (len,);
}

// @notice function to get the return amounts for a number of specified trades and routers
// @param _routers - The router types and router addresses of the DEX routers to utilize
// @param _token_in - The address of the token to sell
// @param _token_out - The address of the token to buy
// @param _amount_in - The amount of token_in to sell
// @return _amount_out - An array of amounts of token_out that would be received for each given trade
@view
func get_amount_from_provided_routers{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    _routers_len: felt, _routers: Router*, _token_in: felt, _token_out: felt, _amount_in: Uint256
) -> (_amounts_out_len: felt, _amounts_out: Uint256*) {
    alloc_locals;

    let (local _amounts_out: Uint256*) = alloc();

    RouterAggregator.amounts_from_provided_routers(
        _routers_len, _routers, _token_in, _token_out, _amount_in, _routers_len, _amounts_out
    );

    return (_routers_len, _amounts_out);
}

// @notice For a given token trade return the best return amount and router known to the aggregator
// @param _amount_in - The router types and router addresses of the DEX routers to utilize
// @param _token_in - The address of the token to sell
// @param _token_out - The address of the token to buy
// @return amount_out - The amount of tokens returned by the best router
// @return router - The best router address and type
@view
func get_single_best_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _token_in: felt, _token_out: felt
) -> (amount_out: Uint256, router: Router) {
    let (router_len) = router_index_len.read();

    let (res_amount: Uint256, res_router) = RouterAggregator.find_best_router(
        _amount_in,
        _token_in,
        _token_out,
        _best_amount=Uint256(0, 0),
        _router=Router(0, 0),
        _router_len=router_len,
    );

    return (res_amount, res_router);
}

// @notice For a given token trade return the best return amount and router from a saved list of high liquidity DEXes
// @param _amount_in - The router types and router addresses of the DEX routers to utilize
// @param _token_in - The address of the token to sell
// @param _token_out - The address of the token to buy
// @return amount_out - The amount of tokens returned by the best router
// @return router - The best router address and type
@view
func get_single_best_top_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _token_in: felt, _token_out: felt
) -> (amount_out: Uint256, router: Router) {
    let (router_len) = router_index_len.read();

    let (res_amount: Uint256, res_router) = RouterAggregator.find_best_top_router(
        _amount_in,
        _token_in,
        _token_out,
        _best_amount=Uint256(0, 0),
        _router=Router(0, 0),
        _router_len=router_len,
    );

    return (res_amount, res_router);
}

// @notice For a given token trade return all routers that have liquidity for that pair as well as the expected return amounts
// @param _amount_in - The router types and router addresses of the DEX routers to utilize
// @param _token_in - The address of the token to sell
// @param _token_out - The address of the token to buy
// @return amounts_out - An array of token amounts returned by all routers with liquidity for the given pair
// @return routers - An array of addresses and types of all routers with liquidity for the given pair
@view
func get_all_routers_and_amounts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _token_in: felt, _token_out: felt
) -> (amounts_out_len: felt, amounts_out: Uint256*, routers_len: felt, routers: Router*) {
    alloc_locals;

    let (amounts: Uint256*) = alloc();
    let (routers: Router*) = alloc();

    // Number of saved routers
    let (routers_len: felt) = router_index_len.read();

    // Fill amounts and router arrs, get
    RouterAggregator.all_routers_and_amounts(
        _amount_in, _token_in, _token_out, amounts, routers, routers_len
    );

    return (routers_len, amounts, routers_len, routers);
}

// @notice for a given token pair, return the available token reserves of each DEX
// @param token_a - The address of token A
// @param token_b - The address of token B
// @return reserve_a - The amount of token_a that are available in the token pair
// @return reserve_b - The amount of token_b that are available in the token pair
@view
func get_all_routers_and_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token_a: felt, _token_b: felt
) -> (
    reserves_a_len: felt,
    reserves_a: Uint256*,
    reserves_b_len: felt,
    reserves_b: Uint256*,
    routers_len: felt,
    routers: Router*,
) {
    alloc_locals;

    let (reserves_a: Uint256*) = alloc();
    let (reserves_b: Uint256*) = alloc();
    let (routers: Router*) = alloc();

    // Number of saved routers
    let (routers_len: felt) = router_index_len.read();

    // Fill amounts and router arrs
    let actual_router_len = RouterAggregator.all_routers_and_reserves(
        _token_a, _token_b, reserves_a, reserves_b, routers_len, routers, _router_counter=0
    );

    return (
        actual_router_len, reserves_a, actual_router_len, reserves_b, actual_router_len, routers
    );
}

// @notice For a given token, provide the price in USD
// @param _token - Address of token to get the USD price for
// @return price - USD token price scaled to 1e18
// @return decimals - Number of decimals for the provided price (should always be scaled by the router to 1e18)
@view
func get_global_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token: felt
) -> (price: Uint256, decimals: felt) {
    alloc_locals;

    let (feed: Feed) = price_feed.read(_token);
    if (feed.address == 0) {
        // let (res_amount: Uint256,_) = get_single_best_router(1*BASE,_token,ETH)
        return (Uint256(100 * BASE_8, 0), 0);
    }
    let (price, decimals, _, _) = IEmpiricOracle.get_spot_median(feed.address, feed.key);

    with_attr error_message("price_feed result invalid, token: {_token}") {
        assert_not_equal(price, FALSE);
    }

    // We only have 8 decimals atm
    if (decimals == 8) {
        let transformed_price = Utils.felt_fmul(price, BASE, BASE_8);
        tempvar final_price = Uint256(transformed_price, 0);
        return (final_price, decimals);
    } else {
        tempvar final_price = Uint256(price, 0);
        return (final_price, decimals);
    }
}

// @notice Provides a unified weight value for a give token pair to be used by certain algorithms
// @dev This function is made for very specific algorithms (see spf solver) and provides little utility for more general algorithms.
// @param _amount_in_usd - USD value of the assets to be sold
// @param _amount_out - number of assets received
// @param _token_out - address of the token being bought
// @return weight - The normailized weight value for the received amount
@view
func get_weight{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in_usd: Uint256, _amount_out: Uint256, _token_out: felt
) -> (weight: felt) {
    alloc_locals;

    // Transform Token Amount to USD Amount
    // As of now all Empiric prices are scaled to 18 decimal places
    let (price_out: Uint256, _) = get_global_price(_token_out);
    let (value_out: Uint256) = Utils.fmul(_amount_out, price_out, Uint256(BASE, 0));

    // Determine Weight
    let (trade_cost) = uint256_sub(_amount_in_usd, value_out);
    let (route_cost) = Utils.fdiv(trade_cost, _amount_in_usd, Uint256(BASE, 0));

    return (route_cost.low,);
}

// //////////////////////
//       Admin        //
// //////////////////////

// @notice Add a router to the router aggregator
// @dev put a router on the top of the list and increase the router list length
// @param _router_address - Address of the router to be added
// @param _router_type - The type of the router to be added (see lib/consts)
@external
func add_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _router_address: felt, _router_type: felt
) {
    Ownable.assert_only_owner();
    let (router_len) = router_index_len.read();
    routers.write(router_len, Router(_router_address, _router_type));
    router_index_len.write(router_len + 1);
    // EMIT ADD EVENT
    return ();
}

// @notice Update an existing router entry
// @dev The provided id has to be lower then the current number of registered routers
// @param _router_address - Address of the router to be added
// @param _router_type - The type of the router to be added (see lib/consts)
// @param _id - The router_id to be mapped to the new router
@external
func update_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _router_address: felt, _router_type: felt, _id: felt
) {
    Ownable.assert_only_owner();
    let (router_len) = router_index_len.read();
    let is_under_len = is_le_felt(_id, router_len);
    assert is_under_len = 1;
    routers.write(_id, Router(_router_address, _router_type));
    // EMIT ADD EVENT
    return ();
}

// @notice Remove an existing router entry
// @dev The last entry will be poped written at the location of the provided entry id
// @param _id - id of the router to be removed
@external
func remove_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_id: felt) {
    Ownable.assert_only_owner();
    let (router_len) = router_index_len.read();
    let (last_router: Router) = routers.read(router_len);
    routers.write(_id, last_router);
    routers.write(router_len, Router(0, 0));
    router_index_len.write(router_len - 1);
    // EMIT REMOVE EVENT
    return ();
}

// @notice Add a high liquidity (top) router to the router aggregator
// @dev put a router on the top of the list and increase the router list length
// @param _router_address - Address of the router to be added
// @param _router_type - The type of the router to be added (see lib/consts)
@external
func add_top_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _router_address: felt, _router_type: felt
) {
    Ownable.assert_only_owner();
    let (router_len) = top_router_index_len.read();
    top_routers.write(router_len, Router(_router_address, _router_type));
    top_router_index_len.write(router_len + 1);
    // EMIT ADD EVENT
    return ();
}

// @notice Update an existing high liquidity (top) router entry
// @dev The provided id has to be lower then the current number of registered routers
// @param _router_address - Address of the router to be added
// @param _router_type - The type of the router to be added (see lib/consts)
// @param _id - The router_id to be mapped to the new router
@external
func update_top_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _router_address: felt, _router_type: felt, id: felt
) {
    Ownable.assert_only_owner();
    let (router_len) = top_router_index_len.read();
    let is_under_len = is_le_felt(id, router_len);
    assert is_under_len = 1;
    top_routers.write(id, Router(_router_address, _router_type));
    // EMIT ADD EVENT
    return ();
}

// @notice Remove an existing high liquidity (top) router entry
// @dev The last entry will be poped written at the location of the provided entry id
// @param _id - id of the router to be removed
@external
func remove_top_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _index: felt
) {
    Ownable.assert_only_owner();
    let (router_len) = router_index_len.read();
    let (last_router: Router) = top_routers.read(router_len);
    top_routers.write(_index, last_router);
    top_routers.write(router_len, Router(0, 0));
    top_router_index_len.write(router_len - 1);
    // EMIT REMOVE EVENT
    return ();
}

// @notice Store an Emperic USD price oracle for a provided token address
// @param _token - Token address that the oracle will be mapped to
// @param _key - Epheric key of the _token-USD price oracle
// @param _oracle_address - The contract address of the Emperic oracle
@external
func set_global_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token: felt, _key: felt, _oracle_address: felt
) {
    Ownable.assert_only_owner();
    price_feed.write(_token, Feed(_key, _oracle_address));
    // EMIT ADD PRICE FEED EVENT
    return ();
}
