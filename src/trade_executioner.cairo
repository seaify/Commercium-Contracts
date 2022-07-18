%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

from src.openzeppelin.security.safemath import SafeUint256
from src.lib.hub import Swap

from src.interfaces.IERC20 import IERC20
from src.interfaces.IUni_router import IUni_router

const Uni = 1
const Cow = 2

@storage_var 
func get_router_type(router_address: felt)->(router_type: felt):
end

@external
func swap_single{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
    _router_address: felt, _amount_in: Uint256, _token_in: felt, _token_out: felt, _receiver: felt
    ) -> (amount_out: Uint256):
    alloc_locals
    let (this_address) = get_contract_address()

    _swap(_router_address,_amount_in,_token_in,_token_out,_receiver)

    let (amount_out) = IERC20.balanceOf(_token_out,this_address) 
    IERC20.transfer(_token_out,_receiver,amount_out)
    return(amount_out)
end

@external
func multis_swap{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
        _amount_in: Uint256,
        _routers_len : felt,
        _routers : felt*,
        _tokens_in_len : felt, 
        _tokens_in : felt*, 
        _tokens_out_len : felt, 
        _tokens_out : felt*, 
        _trade_executor_address: felt,
        _receiver_address: felt
    ):
    alloc_locals

    if _routers_len == 0 :
        return()
    end
    
    let(local amount_before_trade: Uint256) = IERC20.balanceOf(_tokens_in[0],_receiver_address)

    _swap(_routers[0],_amount_in,_tokens_in[0],_tokens_out[0],_receiver_address)

    let (amount_after_trade: Uint256) = IERC20.balanceOf(_tokens_in[0],_receiver_address)

    let (new_token_amount: Uint256) = SafeUint256.sub_le(amount_after_trade,amount_before_trade)
    
    multis_swap(
        new_token_amount,
        _routers_len-1,
        _routers+1,
        _tokens_in_len, 
        _tokens_in+1, 
        _tokens_out_len, 
        _tokens_out+1, 
        _trade_executor_address,
        _receiver_address
    )
    
    return()
end

func _swap{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
        _router_address: felt,
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _receiver_address: felt
    ): 

    let (router_type) = get_router_type.read(_router_address)

    if router_type == Uni :
        IERC20.approve(_router_address,_receiver_address,_amount_in)
        IUni_router.exchange_exact_token_for_token(_router_address,_amount_in,_token_in,_token_out,0)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr    
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    
    #if router_type == Cow :
    #    ICoW.deposit(_router_address,amount)
    #	ICoW.balance() :
    #end

    return()
end
