%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ITrade_executor:

    func swap_single(_router_address: felt, _router_type: felt, _amount_in: Uint256,_token_in: felt,_token_out: felt, _reciever: felt
        ) -> (amount_out: Uint256):
    end

end
