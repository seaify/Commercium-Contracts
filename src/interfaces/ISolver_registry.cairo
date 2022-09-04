%lang starknet

@contract_interface
namespace ISolver_registry:
    
    #Returns a solver contract address for a given solver ID
    ###
    #Parameters:
    #_solver_id | id of the solver address to receive
    #Return Values:
    #solver_address | address of the solver contract that is mapped to _solver_id
    func get_solver(_solver_id: felt) -> (solver_address: felt):
    end

    func get_next_id() -> (solver_id: felt):
    end

    #Mapp a given solver ID to a given solver address
    ###
    #Parameters:
    #_solver_id      | ID that will be used to retrieve the solver contract address
    #_solver_address | The solver contract address that will be mapped to the given solver ID 
    func set_solver(_solver_id: felt, _solver_address: felt):
    end

    func add_solver(_solver_address: felt)->(id: felt):
    end
end
