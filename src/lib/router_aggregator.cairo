%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.cairo.common.alloc import alloc

from src.interfaces.i_router import (
    IAlphaRouter,
    IJediRouter,
    ISithRouter,
    ITenKRouter,
    IStarkRouter,
)
from src.interfaces.i_factory import IAlphaFactory, IJediFactory, ISithFactory, ITenKFactory
from src.interfaces.i_pool import IAlphaPool, IStarkPool, IJediPool, ITenKPool, ISithPool
from src.lib.utils import Router
from src.lib.constants import JediSwap, SithSwap, AlphaRoad, TenK, StarkSwap, TenKFactory

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

    // @notice Fetch the best single DEX router for a given trade
    // @param _amount_in - The amount of _token_in to be sold
    // @param _token_in - The address of the token to be sold
    // @param _token_out - The address of token to be bought
    // @param _best_amount - Amount used to track which router yields the best amount
    // @param _router - Address to track the best router
    // @param _router_len - Number of routers registered, used to read all routers from storage
    func find_best_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _best_amount: Uint256,
        _router: Router,
        _router_len: felt,
    ) -> (amount_out: Uint256, router: Router) {
        alloc_locals;

        if (_router_len == 0) {
            return (_best_amount, _router);
        }

        // Get routers
        let (router: Router) = routers.read(_router_len-1);

        local best_amount: Uint256;
        local best_router: Router;

        let (amount: Uint256) = get_router_amount(_amount_in, _token_in, _token_out, router);

        let (is_new_amount_better) = uint256_le(_best_amount, amount);
        if (is_new_amount_better == 1) {
            assert best_amount = amount;
            assert best_router = router;
        } else {
            assert best_amount = _best_amount;
            assert best_router = _router;
        }

        let (res_amount, res_router) = find_best_router(
            _amount_in, _token_in, _token_out, best_amount, best_router, _router_len - 1
        );

        return (res_amount, res_router);
    }

    // @notice Fetch the best single DEX router for a given trade
    // @param _amount_in - The amount of _token_in to be sold
    // @param _token_in - The address of the token to be sold
    // @param _token_out - The address of token to be bought
    // @param _best_amount - Amount used to track which router yields the best amount
    // @param _router - Address to track the best router
    // @param _router_len - Number of routers registered, used to read all routers from storage
    func find_best_top_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _best_amount: Uint256,
        _router: Router,
        _router_len: felt,
    ) -> (amount_out: Uint256, router: Router) {
        alloc_locals;

        if (_router_len == 0) {
            return (_best_amount, _router);
        }

        // Get routers
        let (router: Router) = top_routers.read(_router_len-1);

        local best_amount: Uint256;
        local best_router: Router;

        let (amount: Uint256) = get_router_amount(_amount_in, _token_in, _token_out, router);

        let (is_new_amount_better) = uint256_le(_best_amount, amount);
        if (is_new_amount_better == 1) {
            assert best_amount = amount;
            assert best_router = router;
        } else {
            assert best_amount = _best_amount;
            assert best_router = _router;
        }

        let (res_amount, res_router) = find_best_top_router(
            _amount_in, _token_in, _token_out, best_amount, best_router, _router_len - 1
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

        let (amount: Uint256) = get_router_amount(_amount_in, _token_in, _token_out, router);
        assert _amounts[0] = amount;

        all_routers_and_amounts(
            _amount_in, _token_in, _token_out, _amounts + 2, _routers + 2, _routers_len - 1
        );

        return ();
    }

    func amounts_from_provided_routers{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(
        _routers_len: felt,
        _routers: Router*,
        _token_in: felt,
        _token_out: felt,
        _amount_in: Uint256,
        _amounts_out_len: felt,
        _amounts_out: Uint256*
    ) {

        if (_routers_len == 0) {
            return ();
        }

        let (amount: Uint256) = get_router_amount(
            _amount_in, _token_in, _token_out, _routers[0]
        );

        assert _amounts_out[0] = amount;

        amounts_from_provided_routers(
            _routers_len - 1,
            _routers + 2,
            _token_in,
            _token_out,
            _amount_in,
            _amounts_out_len,
            _amounts_out + 2,
        );

        return ();
    }

    // @notice for a given token pair, get all reserves and router for each DEX
    // @param _token_in - The address of token A
    // @param _token_out - The address of token B
    // @param _reserves_a - An empty array of _token_in reserves, that will be filled by this function
    // @param _reserves_b - An empty array of _token_out reserves, that will be filled by this function
    // @param _routers_len - The number of routers to iterate through
    // @param _router - The address and router type of a DEX router
    // @param _kick_counter - Used to count the number of Routers/DEXes that are excluded (as they have 0 reserves)
    func all_routers_and_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _token_in: felt,
        _token_out: felt,
        _reserves_a: Uint256*,
        _reserves_b: Uint256*,
        _routers_len: felt,
        _routers: Router*,
        _router_counter: felt
    ) -> felt {
        alloc_locals;

        if (0 == _routers_len) {
            return (_router_counter);
        }

        // Get router
        let (local router: Router) = routers.read(_routers_len - 1);

        let (local reserve_a: Uint256, local reserve_b: Uint256) = get_router_reserves(
            _token_in, _token_out, router
        );

        //If either of the reserves are 0, we don't return that router
        let is_reserve_a_zero = is_le_felt(reserve_a.low,0);
        let is_reserve_b_zero = is_le_felt(reserve_b.low,0);
        if (is_reserve_a_zero+is_reserve_b_zero != 0) {
            let final_router_len = all_routers_and_reserves(
                _token_in, _token_out, _reserves_a, _reserves_b, _routers_len - 1, _routers, _router_counter
            );
            return (final_router_len);
        }

        assert _routers[0] = router;
        assert _reserves_a[0] = reserve_a;
        assert _reserves_b[0] = reserve_b;

        let final_router_len = all_routers_and_reserves(
            _token_in, _token_out, _reserves_a + 2, _reserves_b + 2, _routers_len - 1, _routers + 2, _router_counter+1
        );

        return (final_router_len);
    }

    func get_router_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256, _token_in: felt, _token_out: felt, _router: Router
    ) -> (amount_out: Uint256) {
        alloc_locals;
        let (path: felt*) = alloc();
        if (_router.type == JediSwap) {
            let (factory_address) = IJediRouter.factory(_router.address);
            let (pair_address) = IJediFactory.get_pair(factory_address, _token_in, _token_out);
            if (pair_address == 0) {
                return (Uint256(0, 0),);
            }
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            let (amounts_len: felt, amounts: Uint256*) = IJediRouter.get_amounts_out(
                _router.address, _amount_in, 2, path
            );
            return (amounts[1],);
        }
        if (_router.type == AlphaRoad) {
            let (factory_address: felt) = IAlphaRouter.getFactory(_router.address);
            let (pair_address: felt) = IAlphaFactory.getPool(
                factory_address, _token_in, _token_out
            );
            if (pair_address == 0) {
                return (Uint256(0, 0),);
            }
            let (reserve_token_0: Uint256, reserve_token_1: Uint256) = IAlphaPool.getReserves(
                pair_address
            );

            let (local token0: felt) = IAlphaPool.getToken0(pair_address);

            if (token0 == _token_in) {
                let (amount_token_0: Uint256) = IAlphaRouter.quote(
                    _router.address, _amount_in, reserve_token_0, reserve_token_1
                );
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
                return (amount_token_0,);
            } else {
                let (amount_token_0: Uint256) = IAlphaRouter.quote(
                    _router.address, _amount_in, reserve_token_1, reserve_token_0
                );
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
                return (amount_token_0,);
            }
        }
        if (_router.type == SithSwap) {
            let (factory_address) = ISithRouter.factory(_router.address);
            let (pair_address) = ISithFactory.pairFor(factory_address, _token_in, _token_out, 0);
            if (pair_address == 0) {
                return (Uint256(0, 0),);
            }
            let (amount_out: Uint256, _) = ISithRouter.getAmountOut(
                _router.address, _amount_in, _token_in, _token_out
            );
            return (amount_out,);
        }
        if (_router.type == TenK) {
            // Surely that will change in the future
            let (factory_address) = ITenKRouter.factory(_router.address);
            let (pair_address) = ITenKFactory.getPair(factory_address, _token_in, _token_out);
            // let (pair_address) = ITenKFactory.getPair(TenKFactory,_token_in,_token_out);
            if (pair_address == 0) {
                return (Uint256(0, 0),);
            }
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            let (amounts_len: felt, amounts: Uint256*) = ITenKRouter.getAmountsOut(
                _router.address, _amount_in, 2, path
            );
            return (amounts[1],);
        }
        if (_router.type == StarkSwap) {
            // let (pair_address) = IStarkRouter.getPair(_router.address,_token_in,_token_out);
            //    if (pair_address == 0) {
            //        return (Uint256(0,0),);
            //    }

            // let (reserve1: Uint256) = IStarkPool.poolTokenBalance(1);
            //    let (reserve2: Uint256) = IStarkPool.poolTokenBalance(2);

            // let (token1: felt) = IStarkPool.TokenA(pair_address);

            // if (token1 == _token_in) {
            //        let (amount_out: Uint256) = IStarkPool.getInputPrice(
            //            pair_address, _amount_in, reserve1, reserve2
            //        );
            //        return (amount_out,);
            //    }
            //    let (amount_out: Uint256) = IStarkPool.getInputPrice(
            //        pair_address, _amount_in, reserve2, reserve1
            //    );
            return (Uint256(0, 0),);
        } else {
            with_attr error_message("TRADE EXECUTIONER: Router type doesn't exist") {
                assert 1 = 2;
            }
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            return (Uint256(0, 0),);
        }
    }

    // @notice for a given token pair and router, return the available token reserves
    // @param token_a - The address of token A
    // @param token_b - The address of token B
    // @param router - The address and router type of a DEX router
    // @return reserve_a - The amount of token_a that are available in the token pair
    // @return reserve_b - The amount of token_b that are available in the token pair
    func get_router_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _token_a: felt, _token_b: felt, _router: Router
    ) -> (reserve_a: Uint256, reserve_b: Uint256) {
        alloc_locals;
        if (_router.type == JediSwap) {
            let (local factory_address) = IJediRouter.factory(_router.address);
            let (pair_address) = IJediFactory.get_pair(factory_address, _token_a, _token_b);
            if (pair_address == 0) {
                return (Uint256(0, 0), Uint256(0, 0));
            }
            let (reserve_a: Uint256, reserve_b: Uint256) = IJediPool.get_reserves(pair_address);
            
            return (reserve_a, reserve_b);
        }
        if (_router.type == AlphaRoad) {
            let (factory_address: felt) = IAlphaRouter.getFactory(_router.address);
            let (pair_address: felt) = IAlphaFactory.getPool(factory_address, _token_a, _token_b);
            if (pair_address == 0) {
                return (Uint256(0, 0), Uint256(0, 0));
            }
            let (reserve_token_0: Uint256, reserve_token_1: Uint256) = IAlphaPool.getReserves(
                pair_address
            );
            return (reserve_token_0, reserve_token_1);
        }
        if (_router.type == SithSwap) {
            let (factory_address) = ISithRouter.factory(_router.address);
            let (pair_address) = ISithFactory.pairFor(factory_address, _token_a, _token_b, 0);
            if (pair_address == 0) {
                return (Uint256(0, 0), Uint256(0, 0));
            }
            let (reserve_token_0, reserve_token_1) = ISithPool.getReserves(pair_address);
            return (reserve_token_0, reserve_token_1);
        }
        if (_router.type == TenK) {
            // Surely that will change in the future
            let (factory_address) = ITenKRouter.factory(_router.address);
            let (pair_address) = ITenKFactory.getPair(factory_address, _token_a, _token_b);
            // let (pair_address) = ITenKFactory.getPair(TenKFactory,_token_a,_token_b);
            if (pair_address == 0) {
                return (Uint256(0, 0), Uint256(0, 0));
            }
            let (reserve_a, reserve_b, _) = ITenKPool.getReserves(pair_address);
            return (reserve_a, reserve_b);
        }
        if (_router.type == StarkSwap) {
            // let (pair_address) = IStarkRouter.getPair(_router.address,_token_in,_token_out);
            //    if (pair_address == 0) {
            //        return (Uint256(0,0),);
            //    }

            // let (reserve1: Uint256) = IStarkPool.poolTokenBalance(1);
            //    let (reserve2: Uint256) = IStarkPool.poolTokenBalance(2);

            // let (token1: felt) = IStarkPool.TokenA(pair_address);

            // if (token1 == _token_in) {
            //        let (amount_out: Uint256) = IStarkPool.getInputPrice(
            //            pair_address, _amount_in, reserve1, reserve2
            //        );
            //        return (amount_out,);
            //    }
            //    let (amount_out: Uint256) = IStarkPool.getInputPrice(
            //        pair_address, _amount_in, reserve2, reserve1
            //    );
            return (Uint256(0, 0), Uint256(0, 0));
        } else {
            with_attr error_message("TRADE EXECUTIONER: Router type doesn't exist") {
                assert 1 = 2;
            }
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            return (Uint256(0, 0), Uint256(0, 0));
        }
    }
}
