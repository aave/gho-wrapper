// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {WrappedGhoToken} from 'src/WrappedGhoToken.sol';

import {WrappedGhoTokenTest} from 'test/unit/WrappedGhoTokenTest.t.sol';
import {SigUtils} from 'test/utils/SigUtils.sol';

/// forge-config: default.fuzz.runs = 256
contract WrappedGhoTokenFork is WrappedGhoTokenTest {
  function setUp() public override {
    vm.createSelectFork(
      vm.rpcUrl('mainnet'),
      vm.envOr('TEST_FORK_BLOCK_NUMBER', uint256(21771780))
    );
    wrappedGho = WrappedGhoToken(
      _deployWrappedGhoProxy(PROXY_ADMIN_OWNER, TOKEN_NAME, TOKEN_SYMBOL)
    );
    underlyingToken = IERC20(GHO);
    sigUtils = new SigUtils(wrappedGho.DOMAIN_SEPARATOR());
  }
}
