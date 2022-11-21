%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak, keccak_uint256s_bigend, keccak_felts_bigend
from starkware.cairo.common.uint256 import Uint256

@external
func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr
    }() -> (evm_address_low: felt, evm_address_high: felt) {
    alloc_locals;

    //Determine evm address using keccak
    //let (keccak_ptr: felt*) = alloc();
    //let (elements: felt*) = alloc();
    //local keccak_ptr_start: felt* = keccak_ptr;
    //with keccak_ptr {
    //    let (evm_contract_address: Uint256) = keccak_felts_bigend(n_elements=1, elements=elements);
    //}

    // Finalize to ensoure prover cannot manipulate result
    //finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);

    %{
        import rlp
        from eth_typing import Address
        from eth_utils import to_checksum_address, big_endian_to_int, int_to_big_endian, decode_hex, is_bytes
        from eth_hash.auto import keccak

        address = Address("0x4F26FfBe5F04ED43630fdC30A87638d53D0b0876")

        value = keccak(rlp.encode([address, 445]))

        trimmed_value = value[-20:]
        padded_value = trimmed_value.rjust(20, b'\x00')

        print("Address: ",big_endian_to_int(padded_value))
    %}
    
    return(1,0);
}