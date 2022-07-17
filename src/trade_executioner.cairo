%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

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

    let (router_type) = get_router_type.read(_router_address)

    if router_type == Uni :
        IERC20.approve(_router_address,this_address,_amount_in)
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
    
    let (amount_out) = IERC20.balanceOf(_token_out,this_address) 
    IERC20.transfer(_token_out,_receiver,amount_out)
    return(amount_out)
end

@external
func multis_swap{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
    _path_len: felt,
    _path: Swap*,
    _trade_executor_address: felt,
    _receiver_address: felt):

    if _path_len == 0 :
        return()
    end
    
    let(trade_amount: Uint256) = IERC20.balanceOf(_path[0].token_in,_receiver_address)

    swap_single(_path[0].router,trade_amount,_path[0].token_in,_path[0].token_out,_receiver_address)
    
    multis_swap(_path_len-1,_path+1,_trade_executor_address,_receiver_address)
    
    return()
end
