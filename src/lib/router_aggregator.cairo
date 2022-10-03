%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_sub
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.usort import usort

from src.openzeppelin.access.ownable import Ownable
from src.interfaces.i_empiric_oracle import IEmpiric_oracle
from src.interfaces.i_router import IAlphaRouter, IJediRouter, ISithRouter, ITenKRouter
from src.interfaces.i_factory import IAlpha_factory, IJedi_factory
from src.interfaces.i_pool import IAlpha_pool, IJedi_pool
from src.lib.utils import Utils, Router, Liquidity, SithSwapRoutes
from src.lib.constants import (BASE, JediSwap, SithSwap, AlphaRoad, TenK)

struct Feed {
    key: felt,
    address: felt,
}

//
// Storage
//

@storage_var
func price_feed(token: felt) -> (feed: Feed) {
}

@storage_var
func routers(index: felt) -> (router: Router) {
}

@storage_var
func router_index_len() -> (len: felt) {
}

namespace RouterAggregator {

    func find_best_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _best_amount: Uint256,
        _router: Router,
        _counter: felt,
    ) -> (amount_out: Uint256, router: Router) {
        alloc_locals;

        let (index) = router_index_len.read();

        if (_counter == index) {
            return (_best_amount, _router);
        }

        // Get routers
        let (router: Router) = routers.read(_counter);

        local best_amount: Uint256;
        local best_router: Router;

        let (amount: Uint256) = get_router_amount(_amount_in,_token_in,_token_out,router);

        let (is_new_amount_better) = uint256_le(_best_amount, amount);
        if (is_new_amount_better == 1) {
            assert best_amount = amount;
            assert best_router = router;
        } else {
            assert best_amount = _best_amount;
            assert best_router = _router;
        }

        // if router.router_type == cow :
        // let (out_amount) = ICow_Router.get_exact_token_for_token(router_address,_amount_in,_token_in,_token_out)
        // end

        let (res_amount, res_router) = find_best_router(
            _amount_in, _token_in, _token_out, best_amount, best_router, _counter + 1
        );

        return (res_amount, res_router);
    }

    func all_routers_and_amounts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _amounts: Uint256*,
        _routers: Router*,
        _routers_len: felt,
    ) {
        alloc_locals;

        if (0 == _routers_len) {
            return ();
        }

        // Get router
        let (router: Router) = routers.read(_routers_len - 1);

        // Add rounter to routers arr
        assert _routers[0] = router;

        let (amount: Uint256) = get_router_amount(_amount_in,_token_in,_token_out,router);
        assert _amounts[0] = amount;

        all_routers_and_amounts(
            _amount_in, _token_in, _token_out, _amounts + 2, _routers + 2, _routers_len - 1
        );

        return ();
    }

    func all_routers_and_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _token_in: felt,
        _token_out: felt,
        _liquidity: Liquidity*,
        _routers: Router*,
        _routers_len: felt,
    ) {
        alloc_locals;

        if (0 == _routers_len) {
            return ();
        }

        // Get router
        let (router: Router) = routers.read(_routers_len - 1);

        // Add rounter to routers arr
        assert _routers[0] = router;

        let (liquidity: Liquidity) = get_router_liquidity(_token_in,_token_out,_routers[0]);
        assert _liquidity[0] = liquidity;

        all_routers_and_liquidity(
            _token_in, _token_out, _liquidity + 4, _routers + 2, _routers_len - 1
        );

        return ();
    }

    func get_router_amount{
            syscall_ptr: felt*, 
            pedersen_ptr: HashBuiltin*, 
            range_check_ptr
        }(
            _amount_in: Uint256,
            _token_in: felt,
            _token_out: felt,
            _router: Router
        ) -> (amount_out: Uint256) {

        let (path: felt*) = alloc();

        if (_router.type == JediSwap) {
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            let (amounts_len: felt, amounts: Uint256*) = IJediRouter.get_amounts_out(
                _router.address, _amount_in, 2, path
            );
            return (amounts[1],);
        }
        if (_router.type == AlphaRoad){
            let (factory_address: felt) = IAlphaRouter.getFactory(_router.address);
            let (pair_address: felt) = IAlpha_factory.getPool(factory_address,_token_in,_token_out);
            let (reserve_token_0: Uint256, reserve_token_1: Uint256) = IAlpha_pool.getReserves(pair_address);
            let (amount_token_0: Uint256) = IAlphaRouter.quote(
                _router.address,
                _amount_in, 
                reserve_token_0, 
                reserve_token_1
            );
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            return (amount_token_0,);
        }
        if (_router.type == SithSwap) {
            let (amount_out: Uint256, _) = ISithRouter.getAmountOut(
                _router.address, 
                _amount_in, 
                _token_in,
                _token_out
            );
            return (amount_out,);
        }
        if (_router.type == TenK) {
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            let (amounts_len: felt, amounts: Uint256*) = ITenKRouter.getAmountsOut(
                _router.address, _amount_in, 2, path
            );
            return (amounts[1],);
        } else {
            with_attr error_message("TRADE EXECUTIONER: Router type doesn't exist") {
                assert 1 = 2;
            }
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            return (Uint256(0,0),);
        }
    }

    func get_router_amount_in{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_out: Uint256,
        _token_in: felt,
        _token_out: felt,
        _router: Router
    ) -> (amount_out: Uint256) {

        if (_router.type == JediSwap) {
            let (path: felt*) = alloc();
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            let (amounts_len: felt, amounts: Uint256*) = IJediRouter.get_amounts_in(
                _router.address, _amount_out, 2, path
            );
            return (amounts[0],);
        }
        if (_router.type == AlphaRoad){

            //Waiting for alpha road to release their 

            with_attr error_message("Router Aggregator Lib: Alpha Road currently not implemented") {
                assert 1 = 2;
            }
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            return (Uint256(0,0),);
        } else {
            with_attr error_message("Router Aggregator Lib: Router type doesn't exist") {
                assert 1 = 2;
            }
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            return (Uint256(0,0),);
        }
    }

    func get_router_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
            _token_in: felt,
            _token_out: felt,
            _router: Router
        ) -> (liquidity: Liquidity) {
        alloc_locals;

        if (_router.type == JediSwap) {
            let (factory_address: felt) = IJediRouter.factory(_router.address);
            let (pair_address: felt) = IJedi_factory.get_pair(factory_address,_token_in,_token_out);
            let (local reserve0: Uint256,local reserve1: Uint256,_) = IJedi_pool.get_reserves(pair_address);
            let (token0) = IJedi_pool.token0(pair_address);
            if (token0 == _token_in) {
                return(Liquidity(reserve0, reserve1),);
            } else {
                return(Liquidity(reserve1, reserve0),);
            }
        } 
        if (_router.type == AlphaRoad) {
            let (factory_address: felt) = IAlphaRouter.getFactory(_router.address);
            let (pair_address: felt) = IAlpha_factory.getPool(factory_address,_token_in,_token_out);
            let (local reserve0: Uint256,local reserve1: Uint256) = IAlpha_pool.getReserves(pair_address);
            let (token0) = IAlpha_pool.token0(pair_address);
            if (token0 == _token_in) {
                return(Liquidity(reserve0, reserve1),);
            } else {
                return(Liquidity(reserve1, reserve0),);
            }
        } else {
            with_attr error_message("router type invalid: {ids.router.type}") {
                assert 1 = 0;
            }
            return(Liquidity(Uint256(0, 0),Uint256(0, 0)),);
        }
    }

}