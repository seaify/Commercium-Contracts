// SPDX-License-Identifier: MIT

%lang starknet

// Not actual max felt, just a large feasible number for Uint256
const MAX_FELT = 340282366920938463463374607431768211454;
// Half of the number above
const HALF_MAX = 340282366920938463463374607431768211454 / 2;
const BASE = 1000000000000000000;  // 1e18
const BASE_8 = 100000000;  // 1e8

// ///////////////////
//   Router Types  //
// ///////////////////

// Once we have deploy scripts again, we should make this storage vars
const JediSwap = 0;
const TenK = 1;

// Factories
const TenKFactory = 792675439340753442503309894392665475159403042210985696167998939160953653154;  // 0x01c0a36e26a8f822e0d81f20a5a562b16a8f8a3dfd99801367dd2aea8f1a87a2