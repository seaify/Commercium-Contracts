%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

const multi_call_selector = 558079996720636069421427664524843719962060853116440040296815770714276714984
const simulate_multi_swap_selector = 1310124106700095074905752334807922719347974895149925748802193060450827293357

const Uni = 1

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

    func set_solver_registry{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(new_registry: felt):
        Hub_solver_registry.write(new_registry)
        return()
    end 

    func set_router_type{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(_router_type: felt, _router_address: felt):
        Hub_router_type.write(_router_address,_router_type)
        return()
    end 

end
