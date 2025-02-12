// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';

contract InitializableMock is Initializable {}
contract InitializableWithInitializerMock is Initializable {
  function initialize() public initializer {}
}
contract InitializableWithReinitializerMock is Initializable {
  function initialize(uint64 version) public reinitializer(version) {}
}
