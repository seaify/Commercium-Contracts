%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

namespace Array {
    // Updates one specific entry of an array
    func update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _new_arr_len: felt,
        _new_arr: felt*,
        _arr_len: felt,
        _arr: felt*,
        _index: felt,
        _new_val: felt,
        _counter: felt,
    ) {
        // TEMPORARY
        alloc_locals;

        if (_new_arr_len == _counter) {
            return ();
        }

        if (_index == _counter) {
            assert _new_arr[0] = _new_val;
        } else {
            assert _new_arr[0] = _arr[0];
        }

        update(_new_arr_len, _new_arr + 1, _arr_len, _arr + 1, _index, _new_val, _counter + 1);

        return ();
    }

    // Adds one entry to the end of the array
    func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _new_arr_len: felt, _new_arr: felt*, _arr_len: felt, _arr: felt*, _new_val: felt
    ) -> () {
        if (_new_arr_len == 0) {
            return ();
        }

        if (_new_arr_len == 1) {
            assert _new_arr[0] = _new_val;
        } else {
            assert _new_arr[0] = _arr[0];
        }

        push(_new_arr_len - 1, _new_arr + 1, _arr_len, _arr + 1, _new_val);

        return ();
    }

    // Removes the first entry in the array, shifting every entry down one entry
    // Returns the value of the first entry that was removed
    func shift{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _new_arr_len: felt,
        _new_arr: felt*,
        _arr_len: felt,
        _arr: felt*,
        _return_val: felt,
        _counter: felt,
    ) -> (shifted_val: felt) {
        alloc_locals;

        if (_arr_len == _counter) {
            return (_return_val,);
        }

        if (_new_arr_len == _counter) {
            assert _new_arr[0] = 0;
        } else {
            assert _new_arr[0] = _arr[1];
        }

        local new_return_val;

        if (_counter == 0) {
            assert new_return_val = _arr[0];
        } else {
            assert new_return_val = _return_val;
        }

        let (return_val) = shift(
            _new_arr_len, _new_arr + 1, _arr_len, _arr + 1, new_return_val, _counter + 1
        );

        return (return_val,);
    }
}
