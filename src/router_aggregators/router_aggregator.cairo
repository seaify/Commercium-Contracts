%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_sub
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.usort import usort
from starkware.cairo.common.math_cmp import is_le_felt

from src.openzeppelin.access.ownable import Ownable
from src.interfaces.i_empiric_oracle import IEmpiricOracle
from src.lib.utils import Utils, Router, Liquidity
from src.lib.constants import BASE
from src.lib.router_aggregator import (RouterAggregator, Feed, price_feed, routers, router_index_len, top_routers, top_router_index_len)

//
// Views
//

@view
func get_price_feed{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(_token: felt) -> (feed: Feed){
    let (feed: Feed) = price_feed.read(_token);
    return(feed,);
}

@view
func get_router{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(_index: felt) -> (router_address: felt, router_type: felt) {
    let (router: Router) = routers.read(_index);

    return (router.address,router.type);
}

@view 
func get_router_index_len{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }()->(len: felt){
    let (len) = router_index_len.read();
    return(len,);
}

@view
func get_single_best_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt
    ) -> (amount_out: Uint256, router: Router) {
    let (res_amount: Uint256, res_router) = RouterAggregator.find_best_router(
        _amount_in,
        _token_in,
        _token_out,
        _best_amount=Uint256(0, 0),
        _router=Router(0, 0),
        _counter=0,
    );

    return (res_amount, res_router);
}

@view
func get_single_best_top_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt
    ) -> (amount_out: Uint256, router: Router) {
    let (res_amount: Uint256, res_router) = RouterAggregator.find_best_top_router(
        _amount_in,
        _token_in,
        _token_out,
        _best_amount=Uint256(0, 0),
        _router=Router(0, 0),
        _counter=0,
    );

    return (res_amount, res_router);
}

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

// Returns token price in USD
@view
func get_global_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token: felt
) -> (price: Uint256, decimals: felt) {
    alloc_locals;

    let (feed: Feed) = price_feed.read(_token);
    let (price, decimals, _, _) = IEmpiricOracle.get_value(feed.address, feed.key, 0);

    // IF EMPIRIC INTORDUCES DIFFERENT DECIMALS, WE HAVE TO DO A TRANSFORMATION HERE

    with_attr error_message("price_feed result invalid, token: {_token}") {
        assert_not_equal(price, FALSE);
    }

    return (Uint256(price, 0), decimals);
}

@view
func get_weight{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in_usd: Uint256, 
        _amount_out: Uint256, 
        _token_out: felt
    )->(weight: felt) {
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

//
// Admin
//

@external
func add_router{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(_router_address: felt, _router_type: felt){
    Ownable.assert_only_owner();
    let (router_len) = router_index_len.read();
    routers.write(router_len, Router(_router_address, _router_type));
    router_index_len.write(router_len + 1);
    // EMIT ADD EVENT
    return ();
}

@external
func update_router{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(_router_address: felt, _router_type: felt, id: felt){
    Ownable.assert_only_owner();
    let (router_len) = router_index_len.read();
    let is_under_len = is_le_felt(id,router_len);
    assert is_under_len = 1;
    routers.write(id, Router(_router_address, _router_type));
    //EMIT ADD EVENT
    return();
}

@external
func remove_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_index: felt) {
    Ownable.assert_only_owner();
    let (router_len) = router_index_len.read();
    let (last_router: Router) = routers.read(router_len);
    routers.write(_index, last_router);
    routers.write(router_len, Router(0, 0));
    router_index_len.write(router_len - 1);
    // EMIT REMOVE EVENT
    return ();
}

@external
func add_top_router{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(_router_address: felt, _router_type: felt){
    Ownable.assert_only_owner();
    let (router_len) = top_router_index_len.read();
    top_routers.write(router_len, Router(_router_address, _router_type));
    top_router_index_len.write(router_len + 1);
    // EMIT ADD EVENT
    return ();
}

@external
func update_top_router{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(_router_address: felt, _router_type: felt, id: felt){
    Ownable.assert_only_owner();
    let (router_len) = top_router_index_len.read();
    let is_under_len = is_le_felt(id,router_len);
    assert is_under_len = 1;
    top_routers.write(id, Router(_router_address, _router_type));
    //EMIT ADD EVENT
    return();
}

@external
func remove_top_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_index: felt) {
    Ownable.assert_only_owner();
    let (router_len) = router_index_len.read();
    let (last_router: Router) = top_routers.read(router_len);
    top_routers.write(_index, last_router);
    top_routers.write(router_len, Router(0, 0));
    top_router_index_len.write(router_len - 1);
    // EMIT REMOVE EVENT
    return ();
}

@external
func set_global_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token: felt, _key: felt, _oracle_address: felt
) {
    Ownable.assert_only_owner();
    price_feed.write(_token, Feed(_key, _oracle_address));
    // EMIT ADD PRICE FEED EVENT
    return ();
}
