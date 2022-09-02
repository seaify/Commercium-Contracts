%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (Uint256, uint256_le, uint256_sub)
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.usort import usort

from src.lib.hub import Uni
from src.openzeppelin.access.ownable import Ownable
from src.interfaces.IUni_router import IUni_router
from src.interfaces.IEmpiric_oracle import IEmpiric_oracle
from src.lib.utils import Utils
from src.lib.constants import BASE

struct Router:
    member address: felt
    member type: felt
end

struct Feed:
    member key: felt
    member address : felt
end

@storage_var
func price_feed(token: felt) -> (feed: Feed):
end

@storage_var
func routers(index: felt) -> (router: Router):
end

@storage_var
func router_index_len() -> (len: felt): 
end

#
#Storage
#

namespace RouterAggregator:

    func find_best_router{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(
            _amount_in: Uint256, 
            _token_in: felt, 
            _token_out: felt, 
            _best_amount: Uint256, 
            _router_address: felt, 
            _router_type: felt, 
            _counter: felt
        ) -> (
            amount_out: Uint256, 
            router_address: felt, 
            router_type: felt
        ):
        alloc_locals

        let (index) = router_index_len.read()

        if _counter == index :
            return(_best_amount, _router_address, _router_type)
        end

        #Get routers
        let (router: Router) = routers.read(_counter)

        local best_amount: Uint256
        local best_type : felt
        local best_router: felt

        #Check type and act accordingly
        #Will likely requrie an individual check for each type of AMM, as the interfaces might be different as well as the decimal number of the fees
        if router.type == Uni :
            let (path : felt*) = alloc()
            assert path[0] = _token_in
            assert path[1] = _token_out
            let (_,amounts_out: Uint256*) = IUni_router.get_amounts_out(router.address,_amount_in,2,path)
            let (is_new_amount_better) = uint256_le(_best_amount,amounts_out[1])
            if is_new_amount_better == 1:
                assert best_amount = amounts_out[1]
                assert best_type = router.type
                assert best_router = router.address
            else:
                assert best_amount = _best_amount
                assert best_type = _router_type
                assert best_router = _router_address
            end
                tempvar range_check_ptr = range_check_ptr
                tempvar syscall_ptr = syscall_ptr
                tempvar pedersen_ptr = pedersen_ptr
        else:
            with_attr error_message("router type invalid: {ids.router.type}"):
                assert 1 = 0
            end
            tempvar range_check_ptr = range_check_ptr 	
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr    
        end

        #if router.router_type == cow :
            #let (out_amount) = ICow_Router.get_exact_token_for_token(router_address,_amount_in,_token_in,_token_out)
        #end

        let (res_amount,res_router_address,res_type) = find_best_router(_amount_in,_token_in,_token_out,best_amount,best_router,best_type,_counter+1)
        return(res_amount,res_router_address,res_type)
    end

    func all_routers_and_amounts{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(
            _amount_in: Uint256, 
            _token_in: felt, 
            _token_out: felt,
            _amounts: Uint256*, 
            _routers: Router*,
            _routers_len: felt
        ):
        alloc_locals

        if 0 == _routers_len :
            return()
        end

        #Get router
        let (router: Router) = routers.read(_routers_len-1)

        #Add rounter to routers arr
        assert _routers[0] = router

        if router.type == Uni :
            let (path : felt*) = alloc()
            assert path[0] = _token_in
            assert path[1] = _token_out
            let (_,amounts_out: Uint256*) = IUni_router.get_amounts_out(router.address,_amount_in,2,path)
            assert _amounts[0] = amounts_out[1]
            tempvar range_check_ptr = range_check_ptr 	
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr 
        else:
            with_attr error_message("router type invalid: {ids.router.type}"):
                assert 1 = 0
            end
            tempvar range_check_ptr = range_check_ptr 	
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr    
        end

        all_routers_and_amounts(
            _amount_in, 
            _token_in, 
            _token_out,
            _amounts+2, 
            _routers+2, 
            _routers_len-1
        )

        return()
    end   
     
    #ALTERNATIVE SORTING METHOD...propably better with larger number of solvers
    #@view
    #func get_all_routers_sorted{
    #        syscall_ptr : felt*, 
    #        pedersen_ptr : HashBuiltin*, 
    #        range_check_ptr
    #    }(
    #        _amount_in: Uint256, 
    #        _token_in: felt, 
    #        _token_out: felt
    #    ) -> (
    #        amounts_out_len: felt,
    #        amounts_out: Uint256,
    #        router_addresses_len: felt,  
    #        router_addresses: felt, 
    #        router_types: felt
    #        router_type: felt
    #    ):
    #    alloc_locals

    #    let (amounts : Uint256*) = alloc()
    #    let (routers : Router*) = alloc()

        #Number of saved routers
    #    let (routers_len: felt) = router_index_len.read()

        #Fill amounts and router arrs
    #    all_routers_and_amounts(
    #        _amount_in,
    #        _token_in,
    #        _token_out,
    #        amounts,
    #        routers,
    #        routers_len
    #    )

        #Append ids to amounts
    #    let (modified_amounts: felt*) = append_counter(amounts,routers_len)

        #sort amounts
    #    let (_, amounts_sorted: felt*, _) = usort(routers_len,modified_amounts)

        #remove last numbers
    #    let (final_amounts: felt*, removed_digits: felt*) = remove_digit_counter(amounts_sorted,routers_len)
        
        #build new router_address and types
    #    let (routers) = sort_arr_with_ids(routers,removed_digits)
        
    #    return(final_amounts,routers)
    #end

end
