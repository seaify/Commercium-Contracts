%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.lib.router_aggregator import Router, Liquidity

@contract_interface
namespace IRouter_aggregator {
    func get_single_best_router(
            in_amount: Uint256, 
            token_in: felt, 
            token_out: felt
        )->(amount_out: Uint256, router: Router){
    }

    func get_all_routers_and_amounts(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt
    )->(
        amounts_out_len: felt, 
        amounts_out: Uint256*, 
        routers_len: felt, 
        routers: Router*
    ){
    }

    func get_all_routers_and_amounts_in(
            _amount_out: Uint256, 
            _token_in: felt, 
            _token_out: felt
        )->(
            amounts_in_len: felt, 
            amounts_in: Uint256*, 
            routers_len: felt, 
            routers: Router*
        ){
    }

    func get_all_routers_and_liquidity(_token_in: felt, _token_out: felt)->(
            liquidity_len: felt, 
            liquidity: Liquidity*, 
            routers_len: felt, 
            routers: Router*
        ){
    }

    func get_weight(
            _amount_in_usd: Uint256, 
            _amount_out: Uint256, 
            _token_out: felt
        )->(weight: felt){
    }

    func get_global_price(token: felt)->(price: Uint256, decimals: felt) {
    }

    func get_liquidity_weight(
            _amount_in: Uint256, 
            _src: felt, 
            _dst: felt, 
            _router_address: felt, 
            _router_type: felt
        ) -> (weight: felt){
    }

    func add_router(_router_address: felt, _router_type: felt) {
    }

    func set_global_price(
            _token: felt, 
            _key: felt, 
            _oracle_address: felt
        ){
    }
}
