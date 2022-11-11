%lang starknet

@contract_interface
namespace ISolverRegistry {
    func get_solver(_solver_id: felt) -> (solver_address: felt) {
    }

    func get_next_id() -> (solver_id: felt) {
    }

    func add_solver(_solver_address: felt) -> (id: felt) {
    }

    func set_solver(_solver_id: felt, _solver_address: felt) {
    }
}
