%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.router_aggregator import Feed
from src.lib.utils import Router, Liquidity


@contract_interface
namespace IRouterAggregator {
    func get_price_feed(_token: felt) -> (feed: Feed) {
    }

    func get_router(_index: felt) -> (router_address: felt, router_type: felt) {
    }

    func get_router_index_len() -> (len: felt) {
    }

    func get_single_best_router(_amount_in: Uint256, _token_in: felt, _token_out: felt) -> (
        amount_out: Uint256, router: Router
    ) {
    }

    func get_all_routers_and_amounts(_amount_in: Uint256, _token_in: felt, _token_out: felt) -> (
        amounts_out_len: felt, amounts_out: Uint256*, routers_len: felt, routers: Router*
    ) {
    }

    func get_global_price(_token: felt) -> (price: Uint256, decimals: felt) {
    }

    func get_weight(_amount_in_usd: Uint256, _amount_out: Uint256, _token_out: felt) -> (
        weight: felt
    ) {
    }

    func add_router(_router_address: felt, _router_type: felt) {
    }

    func update_router(_router_address: felt, _router_type: felt, id: felt) {
    }

    func remove_router(_index: felt) {
    }

    func set_global_price(_token: felt, _key: felt, _oracle_address: felt) {
    }
}
