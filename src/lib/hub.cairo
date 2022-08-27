%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.openzeppelin.security.reentrancy_guard import ReentrancyGuard
from src.openzeppelin.security.safemath import SafeUint256
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from src.interfaces.ISolver import ISolver
from src.interfaces.ISolver_registry import ISolver_registry
from src.interfaces.IERC20 import IERC20
from src.interfaces.ITrade_executioner import ITrade_executioner

const multi_call_selector = 558079996720636069421427664524843719962060853116440040296815770714276714984
const simulate_multi_swap_selector = 1310124106700095074905752334807922719347974895149925748802193060450827293357

const Uni = 1

#
#Storage
#

@storage_var
func Hub_trade_executor() -> (trade_executor_address: felt):
end

@storage_var
func Hub_solver_registry() -> (registry_address : felt):
end

@storage_var 
func Hub_router_type(router_address: felt)->(router_type: felt):
end

namespace Hub:

    #
    # Views
    #

    func solver_registry{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr}(
        ) -> (solver_registry):
        let (solver_registry) = Hub_solver_registry.read()
        return(solver_registry)
    end

    #
    # Externals
    #

    func swap_with_solver{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(
        _token_in : felt, 
        _token_out : felt, 
        _amount_in : Uint256, 
        _min_amount_out : Uint256,
        _to : felt,
        _solver_id : felt)->(received_amount: Uint256):
        alloc_locals

        ReentrancyGuard._start()

        #Get Solver address that will be used
        let (solver_registry) = Hub.solver_registry()
        let (local solver_address) = ISolver_registry.get_solver(solver_registry,_solver_id)
        with_attr error_message(
            "solver ID invalid"):
            assert_not_equal(solver_address,FALSE)
        end

        #Get Caller Address
        let (caller_address) = get_caller_address()
        #Get Hub Address
        let (this_address) = get_contract_address()
        #Send tokens_in to the hub
        IERC20.transferFrom(_token_in,caller_address,this_address,_amount_in)

        #Check current token balance
        #(Used to determine received amount)
        let(original_balance: Uint256) = IERC20.balanceOf(_token_out,this_address) 

        #Get trading path from the selected solver
        let (router_addresses_len : felt,
            router_addresses : felt*,
            router_types_len : felt,
            router_types : felt*,
            path_len : felt, 
            path : felt*,
            amounts_len : felt, 
            amounts : felt*
        ) = ISolver.get_results(solver_address, _amount_in, _token_in, _token_out)

        #Get trade executor class hash
        let (trade_executor_hash) = Hub_trade_executor.read()

        #Delegate Call: Execute transactions
        ITrade_executioner.library_call_multi_swap(
            trade_executor_hash,
            router_addresses_len,
            router_addresses,
            router_types_len,
            router_types,
            path_len,
            path,
            amounts_len,
            amounts,
            this_address,
            _amount_in
        )
        
        #Check received Amount
        #We do not naively transfer out the entire balance of that token, as the hub might be holding more
        #tokens that it received as rewards or that where mistakenly sent here
        let (new_amount: Uint256) = IERC20.balanceOf(_token_out,this_address) 
        let (received_amount: Uint256) = SafeUint256.sub_le(new_amount,original_balance)

        #Check that tokens received by solver at at least as much as the min_amount_out
        let (is_min_amount_received) = uint256_le(_min_amount_out,received_amount)
        with_attr error_message(
            "Minimum amount not received"):
            assert is_min_amount_received = TRUE
        end
        
        #Transfer _token_out back to caller
        IERC20.transfer(_token_out,_to,received_amount)

        ReentrancyGuard._end()

        return (received_amount)
    end

    func set_solver_registry{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _new_registry: felt) -> ():
        Hub_solver_registry.write(_new_registry)
        return()
    end

    func set_router_type{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _router_type: felt, _router_address: felt) -> ():
        Hub_router_type.write(_router_address,_router_type)
        return()
    end

end
