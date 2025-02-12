// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from 'forge-std/Script.sol';
import {TransparentProxyFactory} from 'solidity-utils/src/contracts/transparent-proxy/TransparentProxyFactory.sol';
import {WrappedGhoToken, IERC20} from 'src/WrappedGhoToken.sol';

contract WrappedGhoTokenScript is Script {
  TransparentProxyFactory constant PROXY_FACTORY =
    TransparentProxyFactory(0xEB0682d148e874553008730f0686ea89db7DA412);
  address constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

  function run() public {
    console2.log('Block Number: ', block.number);
    address proxyAdminOwner = vm.envAddress('PROXY_ADMIN_OWNER');
    string memory tokenName = vm.envString('TOKEN_NAME');
    string memory tokenSymbol = vm.envString('TOKEN_SYMBOL');
    console2.log('PROXY_ADMIN_OWNER:', proxyAdminOwner);
    console2.log('TOKEN_NAME:', tokenName);
    console2.log('TOKEN_SYMBOL:', tokenSymbol);
    vm.startBroadcast();
    address wrappedGhoProxy = _deployWrappedGhoProxy(proxyAdminOwner, tokenName, tokenSymbol);
    vm.stopBroadcast();
    console2.log('WrappedGho', wrappedGhoProxy);
  }

  function _deployWrappedGhoProxy(
    address proxyAdminOwner,
    string memory tokenName,
    string memory tokenSymbol
  ) internal returns (address) {
    return
      PROXY_FACTORY.create(
        address(new WrappedGhoToken()),
        proxyAdminOwner,
        abi.encodeCall(WrappedGhoToken.initialize, (IERC20(GHO), tokenName, tokenSymbol))
      );
  }
}
