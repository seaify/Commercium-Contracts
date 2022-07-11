%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (Uint256, uint256_lt, uint256_le, uint256_add, uint256_sub, uint256_mul, uint256_unsigned_div_rem)
from starkware.cairo.common.alloc import alloc

from src.interfaces.IUni_router import IUni_router
from src.lib.constants import (uni, cow)
from src.lib.utils import Utils

const Uni = 0
const base = 1000000000000000000
# 0.3% fee
const Uni_fee = 3000000000000000 

struct Pair:
    member in_token : felt
    member out_token : felt
end

struct Router:
    member address: felt
    member type: felt
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

    return(router.address)
end

@view
func get_single_best_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _pair: Pair) -> (amount_out: Uint256, router_address: felt, router_type: felt):
    
    let (res_amount:Uint256,res_router_address,res_type) = find_best_router(_amount_in, _pair, _best_amount=Uint256(0,0), _router_address=0, _router_type=0, _counter=0)

    return(res_amount,res_router_address,res_type)
end

#Requires global prices
@view
func get_weight{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _global_prices_len:felt,_global_prices:Uint256*,_amount_in : Uint256,_reserve1:Uint256,_reserve2:Uint256,_fee:felt,_dst:felt,_src:felt)->(weight:felt):
    alloc_locals
 
    let (amount_in_value) = Utils.fmul(_global_prices[_src],_amount_in,Uint256(1,0))

    let (reserve2_value) = Utils.fmul(_reserve2,_global_prices[_dst],Uint256(1,0))

    let (amount_in_feed) = Utils.fmul(amount_in_value,Uint256(_fee,0),Uint256(1,0))

    let (numerator) = Utils.fmul(amount_in_feed,reserve2_value,Uint256(1,0))
    
    let (reserve1_value) = Utils.fmul(_reserve1,_global_prices[_src],Uint256(1,0)) 

    let (based_reserve1_value) = Utils.fmul(reserve1_value,Uint256(1000,0),Uint256(1,0))

    let (denominator,_) = uint256_add(based_reserve1_value,amount_in_feed)

    let (amount_out) = Utils.fdiv(numerator,denominator,Uint256(1,0))

    let (trade_cost) = uint256_sub(amount_in_value,amount_out)

    #tempvar route_cost = 1000*trade_cost.low / amount_in_value.low

    let (route_cost) = Utils.fdiv(trade_cost,amount_in_value,Uint256(1000,0))

    return(route_cost.low)
end

#Calculates weights from liquidity + fees alone
#Appears to not be feasible
@view
func get_liquidity_weight{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _amount_in : Uint256, _token1: felt, _token2: felt, _router_address: felt, _router_type: felt)->(weight:felt):
    alloc_locals

    local weight : felt

    #If Uni type Dex
    if _router_type == Uni :
        let (reserve1: Uint256, reserve2: Uint256) = IUni_router.get_reserves(_router_address,_token1,_token2)
        let (exchange_rate) = Utils.fdiv(reserve1,reserve2,Uint256(base,0))
        
        let (optimal_amount_out: Uint256) = Utils.fmul(_amount_in,exchange_rate,Uint256(base,0))

        let (amount_out: Uint256) = IUni_router.get_amount_out(_router_address,_amount_in,_token1,_token2)

        let (slippage: Uint256) = Utils.fdiv(amount_out,optimal_amount_out,Uint256(base,0))

        let (slippage_weight: Uint256) = uint256_sub(Uint256(base,0),slippage)

        assert weight = slippage_weight.low + Uni_fee

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        #There will be more types
        assert weight = 9999999999999999999999999
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return(weight)
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
#Internal
#

func find_best_router{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _pair: Pair, _best_amount: Uint256, _router_address: felt, _router_type: felt, _counter: felt) -> (amount_out: Uint256, router_address: felt, router_type: felt):

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
    if router.type == uni :
        let (amount_out: Uint256) = IUni_router.get_amount_out(router.address,_amount_in,_pair.in_token,_pair.out_token)
	    let (is_new_amount_better) = uint256_le(_best_amount,amount_out)
        if is_new_amount_better == 1:
            assert best_amount = amount_out
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
        tempvar range_check_ptr = range_check_ptr 	
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr    
    end

    #if router.router_type == cow :
        #let (out_amount) = ICow_Router.get_exact_token_for_token(router_address,_amount_in,_token_in,_token_out)
    #end

    let (res_amount,res_router_address,res_type) = find_best_router(_amount_in,_pair,best_amount,best_router,best_type,_counter+1)
    return(res_amount,res_router_address,res_type)
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
