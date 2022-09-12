// SPDX-License-Identifier: MIT

%lang starknet

const MAX_FELT = 0 - 1;
const HALF_MAX = MAX_FELT / 2; //Does not cause underflow?
const BASE = 1000000000000000000;  // 1e18

####################
#   Router Types   #
####################

const JediSwap = 0;
const AlphaRoad = 1;


//@view
//func read_felts{}()->(max_felt: felt, half_max: felt){
//    return(MAX_FELT,HALF_MAX);
//}
