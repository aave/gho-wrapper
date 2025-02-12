// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from 'forge-std/Test.sol';
import {WrappedGhoTokenScript} from 'script/Deploy.s.sol';

import {TransparentProxyFactory} from 'solidity-utils/src/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {WrappedGhoToken} from 'src/WrappedGhoToken.sol';

import {ERC20Mock} from 'test/mocks/ERC20Mock.sol';
import {SigUtils} from 'test/utils/SigUtils.sol';

contract BaseTest is Test, WrappedGhoTokenScript {
  bytes32 internal constant TYPE_HASH =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');

  SigUtils internal sigUtils;

  TransparentProxyFactory internal transparentProxyFactory;
  WrappedGhoToken internal wrappedGho;
  IERC20 internal underlyingToken;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  address internal PROXY_ADMIN_OWNER = makeAddr('PROXY_ADMIN_OWNER');
  string internal TOKEN_NAME = 'Wrapped GHO';
  string internal TOKEN_SYMBOL = 'WGHO';

  function setUp() public virtual {
    _setUpState();
    wrappedGho = WrappedGhoToken(
      _deployWrappedGhoProxy(PROXY_ADMIN_OWNER, TOKEN_NAME, TOKEN_SYMBOL)
    ); // deploys wrapped gho proxy through factory
    underlyingToken = IERC20(GHO);

    sigUtils = new SigUtils(wrappedGho.DOMAIN_SEPARATOR()); // validate domain separator later
  }

  function _setUpState() internal {
    vm.etch(address(PROXY_FACTORY), address(new TransparentProxyFactory()).code);
    vm.etch(GHO, address(new ERC20Mock('Gho Token', 'GHO')).code);

    vm.label(address(PROXY_FACTORY), 'TransparentProxyFactory');
    vm.label(PROXY_ADMIN_OWNER, 'ProxyAdmin owner');
  }

  function _getProxyAdmin(address proxy) internal view returns (ProxyAdmin) {
    bytes32 ERC1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 adminSlot = vm.load(proxy, ERC1967_ADMIN_SLOT);
    return ProxyAdmin(address(uint160(uint256(adminSlot))));
  }

  function _getProxyImplementationAddress(address proxy) internal view returns (address) {
    bytes32 ERC1967_IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 implSlot = vm.load(proxy, ERC1967_IMPLEMENTATION_SLOT);
    return address(uint160(uint256(implSlot)));
  }

  function _getInitializableVersion(address proxy) internal view returns (uint8) {
    bytes32 INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    return uint8(uint256(vm.load(proxy, INITIALIZABLE_STORAGE)));
  }

  function _isEitherAddressZeroOrWrappedGho(address who) internal view returns (bool) {
    return who == address(0) || who == address(wrappedGho);
  }
}
