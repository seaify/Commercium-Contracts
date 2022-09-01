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
#Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_owner: felt):
    Ownable.initializer(_owner)
    return()
end

#
#Views
#

@view
func get_router{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_index: felt) -> (router_address: felt):

    let (router:Router) = routers.read(_index)

    return(router.address)
end

@view
func get_single_best_router{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt
    ) -> (
        amount_out: Uint256, 
        router_address: felt, 
        router_type: felt
    ):

    let (res_amount:Uint256,res_router_address,res_type) = find_best_router(_amount_in, _token_in, _token_out, _best_amount=Uint256(0,0), _router_address=0, _router_type=0, _counter=0)

    return(res_amount,res_router_address,res_type)
end

@view
func get_all_routers{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt
    ) -> (
        amounts_out_len: felt,
        amounts_out: Uint256*,
        routers_len: felt,  
        routers: Router*
    ):
    alloc_locals

    let (amounts : Uint256*) = alloc()
    let (routers : Router*) = alloc()

    #Number of saved routers
    let (routers_len: felt) = router_index_len.read()

    #Fill amounts and router arrs, get 
    all_routers_and_amounts(
        _amount_in,
        _token_in,
        _token_out,
        amounts,
        routers,
        routers_len
    )

    return(routers_len,amounts,routers_len,routers)
end

#Returns token price in USD
@view
func get_global_price{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_token: felt)->(price: Uint256, decimals: felt):
    alloc_locals
    
    let (feed: Feed) = price_feed.read(_token)
    let (price,decimals,_,_) = IEmpiric_oracle.get_value(feed.address,feed.key,0)

    #IF EMPIRIC INTORDUCES DIFFERENT DECIMALS, WE HAVE TO DO A TRANSFORMATION HERE

    with_attr error_message(
        "price_feed result invalid, token: {_token}"):
        assert_not_equal(price,FALSE)
    end
    
    return(Uint256(price,0),decimals)
end

@view
func get_weight{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in_usd : Uint256, 
        _amount_out : Uint256, 
        _token1: felt, 
        _token2: felt
    )->(weight:felt):
    alloc_locals

    #Transform Token Amount to USD Amount
    #As of now all Empiric prices are scaled to 18 decimal places
    let (price_out: Uint256,_) = get_global_price(_token2)
    let (value_out: Uint256) = Utils.fmul(_amount_out,price_out,Uint256(BASE,0))

    #Determine Weight
    let (trade_cost) = uint256_sub(_amount_in_usd,value_out)
    let (route_cost) = Utils.fdiv(trade_cost,_amount_in_usd,Uint256(BASE,0))

    return(route_cost.low)
end

#
#Admin
#

@external
func add_router{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_router_address: felt, _router_type: felt):
    Ownable.assert_only_owner()
    let (router_len) = router_index_len.read()
    routers.write(router_len,Router(_router_address,_router_type))
    router_index_len.write(router_len+1)
    #EMIT ADD EVENT
    return()
end

@external
func remove_router{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_index: felt):
    Ownable.assert_only_owner()
    let (router_len) = router_index_len.read()
    let (last_router:Router) = routers.read(router_len)
    routers.write(_index,last_router)
    routers.write(router_len,Router(0,0))
    router_index_len.write(router_len-1)
    #EMIT REMOVE EVENT
    return()
end

@external
func set_global_price{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        _token: felt,
        _key: felt, 
        _oracle_address: felt
    ):
    Ownable.assert_only_owner()
    price_feed.write(_token,Feed(_key,_oracle_address))
    #EMIT ADD PRICE FEED EVENT
    return()
end

#
#Internal
#

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