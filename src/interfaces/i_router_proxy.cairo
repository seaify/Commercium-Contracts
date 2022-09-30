%lang starknet

@contract_interface
namespace IRouterProxy {
    func get_implementation_hash() -> (implementation: felt) {
    }

    func get_admin() -> (admin: felt) {
    }

    func set_implementation_hash(_new_implementation: felt) {
    }

    func _set_admin(_new_admin: felt) {
    }

    func __default__(selector: felt, calldata_size: felt, calldata: felt*) -> (
        retdata_size: felt, retdata: felt*
    ) {
    }
}
