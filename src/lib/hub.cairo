%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func Hub_solver_registry() -> (registry_address : felt):
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

    func set_registry{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(new_registry: felt):
        Hub_solver_registry.write(new_registry)
        return()
    end 

end
