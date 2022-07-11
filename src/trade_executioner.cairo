%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

from src.interfaces.IERC20 import IERC20
from src.interfaces.IUni_router import IUni_router

const Uni = 0
const Cow = 1

@external
func swap_single{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _router_address: felt, _router_type: felt,_amount_in: Uint256, _token_in: felt, _token_out: felt, _receiver: felt
    ) -> (amount_out: Uint256):
    alloc_locals
    let (this_address) = get_contract_address()
    if _router_type == Uni :
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
    
    #if _router_type == Cow :
    #    ICoW.deposit(_router_address,amount)
    #	ICoW.balance() :
    #end
    
    let (amount_out) = IERC20.balanceOf(_token_out,this_address) 
    IERC20.transfer(_token_out,_receiver,amount_out)
    return(amount_out)
end

#@external
#func multis_swap
