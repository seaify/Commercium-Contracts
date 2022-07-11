%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from src.interfaces.ISolver import ISolver
from src.interfaces.ISolver_registry import ISolver_registry
from src.interfaces.IERC20 import IERC20

from src.lib.reentrancy import Reentrancy
from src.openzeppelin.access.ownable import Ownable
from src.lib.hub import Hub

#
#Views
#

@view
func solver_registry{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (solver_registry: felt):
    let (solver_registry) = Hub.solver_registry()
    return(solver_registry)
end

@view
func get_contract_caller{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (caller: felt):
    let (caller) = get_caller_address()
    return(caller)
end

#
#Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ):
#    let (owner) = get_caller_address()
#    Ownable.initializer(owner)
    return()
end

#
#Externals
#

@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _token_in : felt, _token_out : felt, _amount_in : Uint256, _min_amount_out : Uint256, _solver_id : felt):

    alloc_locals

    Reentrancy.check()

    #Get Solver address that will be used
    let (solver_registry) = Hub.solver_registry()
    let (solver_registry_result) = ISolver_registry.get_solver(solver_registry,_solver_id)
    
    let (solver_address : felt*) = alloc()
    
    #If Id is not valid, then we assume the given ID to be the address to a solver that the user wants to use
    if solver_registry_result == 0:
    	solver_address[0] = _solver_id 
    else:
    	solver_address[0] = solver_registry_result
    end

    #Get Caller Address
    let (caller_address) = get_caller_address()
    #Get Hub Address
    let (this_address) = get_contract_address()

    #transfer tokens directly to the solver contract
    #IERC20.transferFrom(_token_in,caller_address,solver_address[0],_amount_in) 
    
    #Execute solver logic
    let (result_amount: Uint256) = ISolver.execute_solver(solver_address[0], _amount_in, _token_in, _token_out, this_address)
    
    #Check that tokens received by solver at at least as much as the min_amount_out
    let (min_amount_received) = uint256_le(_min_amount_out,result_amount)
    assert min_amount_received = 1

    #Transfer _token_out back to caller
    #We do not naively transfer out the entire balance of that token, as there hub might be holding
    #tokens that it received as rewards or that where mistakenly sent here
    IERC20.transfer(_token_out,caller_address,result_amount)

    #Depending on storage cost channel this should be revisited.
    #We are assuming that resetting storage back to its original value will refund the storage write costs
    Reentrancy.reset()

    return ()
end

#
#Admin functions
#

@external
func set_registry{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _new_registry: felt) -> ():
    #Ownable.assert_only_owner()
    Hub.set_registry(_new_registry)
    return()
end

@external
func retrieve_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _token_len: felt, _token: felt*, _token_amount_len: felt, _token_amount: Uint256*) -> ():
    #Ownable.assert_only_owner()
    return()
end
