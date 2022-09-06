%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

// Reentrancy Guard
@storage_var
func reentrancy_status() -> (status: felt) {
}

namespace Reentrancy {
    func check{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> () {
        // Check against reentrancy
        let (current_status) = reentrancy_status.read();
        assert current_status = 0;
        reentrancy_status.write(1);
        return ();
    }

    func reset{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> () {
        // Reset reentrancy guard
        reentrancy_status.write(0);
        return ();
    }
}
