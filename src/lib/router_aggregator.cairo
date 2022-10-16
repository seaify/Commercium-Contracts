%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_sub
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.usort import usort

from src.openzeppelin.access.ownable import Ownable
from src.interfaces.i_router import IAlphaRouter, IJediRouter, ISithRouter, ITenKRouter
from src.interfaces.i_factory import IAlphaFactory, IJediFactory, ISithFactory, ITenKFactory
from src.interfaces.i_pool import IAlphaPool, IJediPool, ISithPool, ITenKPool
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

@storage_var
func top_routers(index: felt) -> (router: Router) {
}

@storage_var
func top_router_index_len() -> (len: felt) {
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

    func find_best_top_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _best_amount: Uint256,
        _router: Router,
        _counter: felt,
    ) -> (amount_out: Uint256, router: Router) {
        alloc_locals;

        let (index) = top_router_index_len.read();

        if (_counter == index) {
            return (_best_amount, _router);
        }

        // Get routers
        let (router: Router) = top_routers.read(_counter);

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

        let (res_amount, res_router) = find_best_top_router(
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
            let (factory_address) = IJediRouter.factory(_router.address);
            let (pair_address) = IJediFactory.get_pair(factory_address,_token_in,_token_out);
            if (pair_address == 0) {
                return (Uint256(0,0),);
            }
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            let (amounts_len: felt, amounts: Uint256*) = IJediRouter.get_amounts_out(
                _router.address, _amount_in, 2, path
            );
            return (amounts[1],);
        }
        if (_router.type == AlphaRoad){
            let (factory_address: felt) = IAlphaRouter.getFactory(_router.address);
            let (pair_address: felt) = IAlphaFactory.getPool(factory_address,_token_in,_token_out);
            if(pair_address == 0){
                return (Uint256(0,0),);
            }
            let (reserve_token_0: Uint256, reserve_token_1: Uint256) = IAlphaPool.getReserves(pair_address);
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
            let (factory_address) = ISithRouter.factory(_router.address);
            let (pair_address) = ISithFactory.pairFor(factory_address,_token_in,_token_out,0);
            let (is_pair) = ISithFactory.isPair(factory_address,pair_address);
            if (is_pair == 0) {
                return (Uint256(0,0),);
            }
            let (amount_out: Uint256, _) = ISithRouter.getAmountOut(
                _router.address, 
                _amount_in, 
                _token_in,
                _token_out
            );
            return (amount_out,);
        }
        if (_router.type == TenK) {
            let (factory_address) = ITenKRouter.factory(_router.address);
            let (pair_address) = ITenKFactory.getPair(factory_address,_token_in,_token_out);
            if (pair_address == 0) {
                return (Uint256(0,0),);
            }
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

}