%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

from src.openzeppelin.security.safemath import SafeUint256
from src.lib.hub import Uni

from src.interfaces.IERC20 import IERC20
from src.interfaces.IUni_router import IUni_router

@external
func multi_swap{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
        _router_addresses_len : felt,
        _router_addresses : felt*,
        _router_types_len: felt,
        _router_types: felt*,
        _tokens_in_len : felt,
        _tokens_in : felt*,
        _tokens_out_len : felt,
        _tokens_out : felt*,
        _amounts_len : felt,
        _amounts : Uint256*,
        _receiver_address: felt
    ):
    alloc_locals

    if _router_addresses_len == 0 :
        return()
    end
    
    let(local amount_before_trade: Uint256) = IERC20.balanceOf(_tokens_out[0],_receiver_address)  
    let(local in_amount_before_trade: Uint256) = IERC20.balanceOf(_tokens_in[0],_receiver_address) 

    if _router_addresses_len == 1 :
        local temp1:Uint256 = _amounts[0]
        local amount1 = temp1.low
        local amount2 = in_amount_before_trade.low
        with_attr error_message("Amounts: {amount1}, in_amount_before_trade: {amount2}"):
            assert 1 = 2
        end
    end 

    _swap(_router_addresses[0],_router_types[0],_amounts[0],_tokens_in[0],_tokens_out[0],_receiver_address)


    let (amount_after_trade: Uint256) = IERC20.balanceOf(_tokens_out[0],_receiver_address)


    let (new_token_amount: Uint256) = SafeUint256.sub_le(amount_after_trade,amount_before_trade)
    
    multi_swap(
        _router_addresses_len-1,
        _router_addresses+1,
        _router_types_len,
        _router_types+1,
        _tokens_in_len,
        _tokens_in+1,
        _tokens_out_len,
        _tokens_out+1, 
        _amounts_len,
        _amounts+2,
        _receiver_address
    )
    
    return()
end

func _swap{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
        _router_address: felt,
        _router_type: felt,
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _receiver_address: felt
    ): 

    if _router_type == Uni :
        IERC20.approve(_token_in,_router_address,_amount_in)
        IUni_router.exchange_exact_token_for_token(_router_address,_amount_in,_token_in,_token_out,Uint256(0,0))
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr    
    else:
        with_attr error_message(
            "TRADE EXECUTIONER: Router type doesn't exist"):
            assert 1 = 2
        end
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
