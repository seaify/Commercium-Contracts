%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_sub
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.usort import usort

from src.openzeppelin.access.ownable import Ownable
from src.interfaces.IEmpiric_oracle import IEmpiric_oracle
from src.interfaces.IRouter import IAlpha_router, IJedi_router
from src.interfaces.IFactory import IAlpha_factory, IJedi_factory
from src.interfaces.IPool import IAlpha_pool, IJedi_pool
from src.lib.utils import Utils, Router, Liquidity
from src.lib.constants import (BASE, JediSwap, AlphaRoad)

struct Feed {
    key: felt,
    address: felt,
}

@storage_var
func price_feed(token: felt) -> (feed: Feed) {
}

@storage_var
func routers(index: felt) -> (router: Router) {
}

@storage_var
func router_index_len() -> (len: felt) {
}

//
// Storage
//

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

    func get_router_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _router: Router
    ) -> (amount_out: Uint256) {

        if (_router.type == JediSwap) {
            let (path: felt*) = alloc();
            assert path[0] = _token_in;
            assert path[1] = _token_out;
            let (amounts_len: felt, amounts: Uint256*) = IJedi_router.get_amounts_out(
                _router.address, _amount_in, 2, path
            );
            return (amounts[1],);
        }
        if (_router.type == AlphaRoad){
            let (factory_address: felt) = IAlpha_router.getFactory(_router.address);
            let (pair_address: felt) = IAlpha_factory.getPool(factory_address,_token_in,_token_out);
            let (reserve_token_0: Uint256, reserve_token_1: Uint256) = IAlpha_pool.getReserves(pair_address);
            let (amount_token_0: Uint256) = IAlpha_router.quote(
                _router.address,
                _amount_in, 
                reserve_token_0, 
                reserve_token_1
            );
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            return (amount_token_0,);
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
            let (amounts_len: felt, amounts: Uint256*) = IJedi_router.get_amounts_in(
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
        ) -> (amount_out: Uint256) {

            if (router.type == JediSwap) {
                let (factory_address: felt) = IJedi_router.factory(_router.address);
                let (pair_address: felt) = IJedi_factory.get_pair(factory_address,_token_in,_token_out);
                let (reserve0: Uint256, reserve1: Uint256,_) = IJedi_pool.get_reserves(pair_address);
                let (token0) = IJedi_pool.token0();
                if (token0 == _token_in) {
                    return(Liquidity(reserve0, reserve1),);
                } else {
                    return(Liquidity(reserve1, reserve0),);
                }
                tempvar range_check_ptr = range_check_ptr;
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
            } 
            if (router.type == AlphaRoad) {
                let (factory_address: felt) = IAlpha_router.getFactory(_router.address);
                let (pair_address: felt) = IAlpha_factory.getPool(factory_address,_token_in,_token_out);
                let (reserve0: Uint256, reserve1: Uint256) = IAlpha_pool.getReserves(pair_address);
                let (token0) = IAlpha_pool.token0();
                if (token0 == _token_in) {
                    return(Liquidity(reserve0, reserve1),);
                } else {
                    return(Liquidity(reserve1, reserve0),);
                }
                return(Liquidity(reserve0, reserve1),);
                tempvar range_check_ptr = range_check_ptr;
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
            } else {
                with_attr error_message("router type invalid: {ids.router.type}") {
                    assert 1 = 0;
                }
                tempvar range_check_ptr = range_check_ptr;
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                return(Liquidity(0, 0),);
            }
    }

    // ALTERNATIVE SORTING METHOD...propably better with larger number of routers
    // @view
    // func get_all_routers_sorted{
    //        syscall_ptr : felt*,
    //        pedersen_ptr : HashBuiltin*,
    //        range_check_ptr
    //    }(
    //        _amount_in: Uint256,
    //        _token_in: felt,
    //        _token_out: felt
    //    ) -> (
    //        amounts_out_len: felt,
    //        amounts_out: Uint256,
    //        router_addresses_len: felt,
    //        router_addresses: felt,
    //        router_types: felt
    //        router_type: felt
    //    ):
    //    alloc_locals

    // let (amounts : Uint256*) = alloc()
    //    let (routers : Router*) = alloc()

    // Number of saved routers
    //    let (routers_len: felt) = router_index_len.read()

    // Fill amounts and router arrs
    //    all_routers_and_amounts(
    //        _amount_in,
    //        _token_in,
    //        _token_out,
    //        amounts,
    //        routers,
    //        routers_len
    //    )

    // Append ids to amounts
    //    let (modified_amounts: felt*) = append_counter(amounts,routers_len)

    // sort amounts
    //    let (_, amounts_sorted: felt*, _) = usort(routers_len,modified_amounts)

    // remove last numbers
    //    let (final_amounts: felt*, removed_digits: felt*) = remove_digit_counter(amounts_sorted,routers_len)

    // build new router_address and types
    //    let (routers) = sort_arr_with_ids(routers,removed_digits)

    // return(final_amounts,routers)
    // end
}