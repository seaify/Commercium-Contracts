%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (Uint256, uint256_lt, uint256_add, uint256_mul, uint256_unsigned_div_rem)
from starkware.cairo.common.alloc import alloc

from src.lib.constants import (uni, cow)
from src.interfaces.IUni_router import IUni_router

struct Incentivizer:
    member router_address : felt
    member percent_incentive : felt
    member balance : Uint256
end

struct Pair:
    member in_token : felt
    member out_token : felt
end

struct Router:
    member router_address: felt
    member router_type: felt
end

@storage_var
func incentivised_pairs(_pair: Pair) -> (incentivizer: Incentivizer):
end

@storage_var
func routers(index: felt) -> (router: Router):
end

@storage_var
func router_index_len() -> (len: felt): 
end

#
#Views
#

@view
func get_router{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _index: felt) -> (router_address: felt):

    let (router:Router) = routers.read(_index)

    return(router.router_address)
end

@view
func get_incentive{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,}(
    _pair: Pair) -> (incentivizer: Incentivizer):
    let (incentivizer: Incentivizer) = incentivised_pairs.read(_pair)
    return(incentivizer)
end

#
@view
func get_single_best_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _pair: Pair) -> (amount_out: Uint256, router_address: felt, router_type: felt):
    
    let (res_amount:Uint256,res_router_address,res_type) = find_best_router(_amount_in, _pair, Uint256(0,0), 0, 0, 0)

    return(res_amount,res_router_address,res_type)
end

#
#Admin (DAO)
#

@external
func add_router{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _router_address: felt, _router_type: felt):
    let (router_len) = router_index_len.read()
    routers.write(router_len,Router(_router_address,_router_type))
    router_index_len.write(router_len+1)
    #EMIT ADD EVENT
    return()
end

@external
func remove_router{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _index: felt):
    let (router_len) = router_index_len.read()
    let (last_router:Router) = routers.read(router_len)
    routers.write(_index,last_router)
    routers.write(router_len,Router(0,0))
    router_index_len.write(router_len-1)
    #EMIT REMOVE EVENT
    return()
end

#
#Admin (Solvers)
#

@external
func payout_incentive{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,}(
    _amount):
    #Admin.only_solvers()
    return()
end


#
#Admin (Auction_contract)
#

@external
func set_incentivization{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _pair : Pair, _incentivizer: Incentivizer)->():
    #Ownable_is_owner()
    
    incentivised_pairs.write(_pair, _incentivizer) 
    return()
end


#
#Internal
#

func find_best_router{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _pair: Pair, _best_amount: Uint256, _router_address: felt, _router_type: felt, _counter: felt) -> (amount_out: Uint256, router_address: felt, router_type: felt):

    alloc_locals

    let (index) = router_index_len.read()

    if _counter == 2 :
        return(_best_amount, _router_address, _router_type)
    end

    #Get routers
    let (router: Router) = routers.read(_counter)

    let (amount_out : Uint256*) = alloc()
    let (new_best_amount : Uint256*) = alloc()
    let (new_type : felt*) = alloc()
    let (new_router: felt*) = alloc()

    #Check type and act accordingly
    #Will likely requrie an individual check for each type of AMM, as the interfaces might be different as well as the decimal number of the fees
    if router.router_type == uni :
        determine_best_uni_amount(0,new_best_amount,0,new_router,0,new_type,0,amount_out,router,_pair,_amount_in,_best_amount,_router_type,_router_address)
        tempvar range_check_ptr = range_check_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        tempvar range_check_ptr = range_check_ptr 	
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr    
    end

    #if router.router_type == cow :
        #let (out_amount) = ICow_Router.get_exact_token_for_token(router_address,_amount_in,_token_in,_token_out)
    #end

    let (res_amount,res_router_address,res_type) = find_best_router(_amount_in,_pair,new_best_amount[0],new_router[0],new_type[0],_counter+1)
    return(res_amount,res_router_address,res_type)
end

func determine_best_uni_amount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,}(
    _new_best_amount_len: felt,
    _new_best_amount: Uint256*,
    _new_router_len: felt,
    _new_router: felt*,
    _net_type_len: felt,
    _new_type: felt*,
    _amount_out_len: felt,
    _amount_out: Uint256*,
    _router: Router,
    _pair: Pair,
    _amount_in: Uint256,
    _best_amount: Uint256,
    _router_type: felt,
    _router_address: felt):
    
    alloc_locals
    let (reserve1,reserve2,fee) = IUni_router.get_pool_stats(_router.router_address,_pair.in_token, _pair.out_token)
    #Get Incentive for token pair direction
    let (incentivizer) = incentivised_pairs.read(_pair)

    let (new_fee : felt*) = alloc()
    if incentivizer.router_address == _router.router_address :
        #incentivizer.fee_incentive
        assert new_fee[0] = fee + 2
    else:
        assert new_fee[0] = fee
    end

    let (res_amount: Uint256) = calc_uni_amount_out(_amount_in,reserve1,reserve2,new_fee[0])
    assert _amount_out[0] = res_amount

    let(is_better) = uint256_lt(_best_amount,_amount_out[0])

    if is_better == 1 :
        assert _new_best_amount[0] = _amount_out[0]
        assert _new_type[0] = _router.router_type
        assert _new_router[0] = _router.router_address
    else:
        assert _new_best_amount[0] = _best_amount
        assert _new_type[0] = _router_type
        assert _new_router[0] = _router_address
    end
    return()
end

func calc_uni_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,}(
    _amount_in: Uint256,_reserve1:Uint256,_reserve2:Uint256,_fee)->(amount_out:Uint256):
    let (feed_amount:Uint256,_) = uint256_mul(_amount_in,Uint256(_fee,0))
    let (numerator,_) = uint256_mul(feed_amount,_reserve2)
    let (feed_reserve,_) = uint256_mul(_reserve1,Uint256(1000,0))
    let (denominator,_) = uint256_add(feed_reserve,feed_amount)
    let (amount_out,_) = uint256_unsigned_div_rem(numerator,denominator)
    return(amount_out)
end
