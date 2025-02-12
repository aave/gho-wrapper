// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Errors} from '@openzeppelin/contracts/interfaces/draft-IERC6093.sol';
import {ITransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {WrappedGhoToken} from 'src/WrappedGhoToken.sol';

import {InitializableMock, InitializableWithInitializerMock, InitializableWithReinitializerMock} from 'test/mocks/InitializableMock.sol';
import {SigUtils} from 'test/utils/SigUtils.sol';

import {BaseTest} from 'test/BaseTest.t.sol';

contract WrappedGhoTokenTest is BaseTest {
  function test_initialize() public {
    assertEq(_getInitializableVersion(address(wrappedGho)), 1);
    assertEq(_getInitializableVersion(_getProxyImplementationAddress(address(wrappedGho))), 255);
    assertEq(
      _getProxyAdmin(address(wrappedGho)).owner(),
      PROXY_ADMIN_OWNER,
      'proxy admin owner is wrong'
    );

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    WrappedGhoToken(_getProxyImplementationAddress(address(wrappedGho))).initialize(
      underlyingToken,
      TOKEN_NAME,
      TOKEN_SYMBOL
    );
  }

  function test_upgrade_success() public {
    ProxyAdmin proxyAdmin = _getProxyAdmin(address(wrappedGho));
    vm.startPrank(proxyAdmin.owner());

    // New version, no initializable call, no new version
    address newImpl = address(new InitializableMock());
    bytes memory mockImpleParams;
    proxyAdmin.upgradeAndCall(
      ITransparentUpgradeableProxy(payable(address(wrappedGho))),
      newImpl,
      mockImpleParams
    );
    assertEq(_getInitializableVersion(address(wrappedGho)), 1);
    assertEq(_getProxyImplementationAddress(address(wrappedGho)), newImpl);

    // New version, initializable call, no new version
    newImpl = address(new InitializableWithInitializerMock());
    mockImpleParams = abi.encodeWithSignature('initialize()');
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    ProxyAdmin(proxyAdmin).upgradeAndCall(
      ITransparentUpgradeableProxy(payable(address(wrappedGho))),
      newImpl,
      mockImpleParams
    );

    // New version, initializable call, new version
    newImpl = address(new InitializableWithReinitializerMock());
    uint64 newVersion = 2;
    mockImpleParams = abi.encodeWithSignature('initialize(uint64)', newVersion);
    ProxyAdmin(proxyAdmin).upgradeAndCall(
      ITransparentUpgradeableProxy(payable(address(wrappedGho))),
      newImpl,
      mockImpleParams
    );
    assertEq(_getInitializableVersion(address(wrappedGho)), newVersion);
    assertEq(_getProxyImplementationAddress(address(wrappedGho)), newImpl);

    vm.stopPrank();
  }

  function test_upgrade_reverts(address caller) public {
    vm.assume(caller != address(_getProxyAdmin(address(wrappedGho))));
    vm.prank(caller);
    vm.expectRevert();
    ITransparentUpgradeableProxy(payable(address(wrappedGho))).upgradeToAndCall(
      address(0),
      bytes('')
    );
    assertEq(_getInitializableVersion(address(wrappedGho)), 1);
  }

  function test_proxyAdmin_transferOwnership_success() public {
    ProxyAdmin proxyAdmin = _getProxyAdmin(address(wrappedGho));
    assertEq(proxyAdmin.owner(), PROXY_ADMIN_OWNER);

    address newOwner = makeAddr('newOwner');
    vm.prank(PROXY_ADMIN_OWNER);
    proxyAdmin.transferOwnership(newOwner);

    assertEq(proxyAdmin.owner(), newOwner, 'Admin owner failed');
  }

  function test_proxyAdmin_transferOwnership_reverts() public {
    ProxyAdmin proxyAdmin = _getProxyAdmin(address(wrappedGho));

    address newOwner = makeAddr('newOwner');
    vm.expectRevert();
    proxyAdmin.transferOwnership(newOwner);

    assertEq(proxyAdmin.owner(), PROXY_ADMIN_OWNER, 'Unauthorized owner change');
  }

  function test_init_params() public view {
    assertEq(wrappedGho.name(), TOKEN_NAME);
    assertEq(wrappedGho.symbol(), TOKEN_SYMBOL);
    assertEq(address(wrappedGho.underlying()), address(underlyingToken));
    assertEq(wrappedGho.decimals(), IERC20Metadata(address(underlyingToken)).decimals());
    assertEq(
      wrappedGho.DOMAIN_SEPARATOR(),
      keccak256(
        abi.encode(
          TYPE_HASH,
          keccak256(bytes(TOKEN_NAME)),
          keccak256(bytes('1')),
          block.chainid,
          address(wrappedGho)
        )
      )
    );
    assertEq(wrappedGho.DOMAIN_SEPARATOR(), sigUtils.DOMAIN_SEPARATOR());
  }

  function test_depositFor_revertsWith_ERC20InvalidSender() public {
    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(wrappedGho))
    );
    vm.prank(address(wrappedGho));
    wrappedGho.depositFor(address(1), 1);
  }

  function test_depositFor_revertsWith_ERC20InvalidReceiver() public {
    address user = makeAddr('user');
    uint256 amount = 1_000e18;
    deal(address(underlyingToken), user, amount);
    vm.startPrank(user);
    underlyingToken.approve(address(wrappedGho), amount);

    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
    wrappedGho.depositFor(address(0), 1);

    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(wrappedGho))
    );
    wrappedGho.depositFor(address(wrappedGho), 1);

    vm.stopPrank();
  }

  function test_depositFor_fuzz_success(address user, address to, uint256 amount) public {
    vm.assume(
      user != to &&
        !_isEitherAddressZeroOrWrappedGho(user) &&
        !_isEitherAddressZeroOrWrappedGho(to) &&
        user != address(_getProxyAdmin(address(wrappedGho)))
    );

    deal(address(underlyingToken), user, amount);
    vm.startPrank(user);
    underlyingToken.approve(address(wrappedGho), amount);

    // underlying
    uint256 senderBalanceBefore = underlyingToken.balanceOf(user);
    uint256 toBalanceBefore = underlyingToken.balanceOf(to);
    uint256 wrapperBalanceBefore = underlyingToken.balanceOf(address(wrappedGho));
    // wrapped
    uint256 senderWBalanceBefore = wrappedGho.balanceOf(user);
    uint256 toWBalanceBefore = wrappedGho.balanceOf(to);
    uint256 totalSupplyBefore = wrappedGho.totalSupply();

    vm.expectEmit(address(wrappedGho));
    emit Transfer(address(0), to, amount);
    wrappedGho.depositFor(to, amount);

    // underlying
    assertEq(
      underlyingToken.balanceOf(user),
      senderBalanceBefore - amount,
      'wrong underlying sender balance'
    );
    assertEq(underlyingToken.balanceOf(to), toBalanceBefore, 'wrong underlying to balance');
    assertEq(
      underlyingToken.balanceOf(address(wrappedGho)),
      wrapperBalanceBefore + amount,
      'wrong underlying wrapper balance'
    );
    // wrapped
    assertEq(wrappedGho.balanceOf(user), senderWBalanceBefore, 'wrong wrapper sender balance');
    assertEq(wrappedGho.balanceOf(to), toWBalanceBefore + amount, 'wrong wrapper to balance');
    assertEq(wrappedGho.totalSupply(), totalSupplyBefore + amount, 'wrong wrapper totalSupply');

    vm.stopPrank();
  }

  function test_withdrawTo_revertsWith_ERC20InvalidReceiver() public {
    address user = makeAddr('user');
    uint256 amount = 1_000e18;

    // prepare scenario with deposit
    deal(address(underlyingToken), user, amount);
    vm.startPrank(user);
    underlyingToken.approve(address(wrappedGho), amount);
    wrappedGho.depositFor(user, amount);

    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(wrappedGho))
    );
    wrappedGho.withdrawTo(address(wrappedGho), 1);

    vm.stopPrank();
  }

  function test_withdrawTo_fuzz_success(address user, address to, uint256 amount) public {
    vm.assume(
      user != to &&
        !_isEitherAddressZeroOrWrappedGho(user) &&
        !_isEitherAddressZeroOrWrappedGho(to) &&
        user != address(_getProxyAdmin(address(wrappedGho)))
    );

    // prepare scenario with deposit
    deal(address(underlyingToken), user, amount);
    vm.startPrank(user);
    underlyingToken.approve(address(wrappedGho), amount);
    wrappedGho.depositFor(user, amount);

    // underlying
    uint256 senderBalanceBefore = underlyingToken.balanceOf(user);
    uint256 toBalanceBefore = underlyingToken.balanceOf(to);
    uint256 wrapperBalanceBefore = underlyingToken.balanceOf(address(wrappedGho));
    // wrapped
    uint256 senderWBalanceBefore = wrappedGho.balanceOf(user);
    uint256 toWBalanceBefore = wrappedGho.balanceOf(to);
    uint256 totalSupplyBefore = wrappedGho.totalSupply();

    vm.expectEmit(address(wrappedGho));
    emit Transfer(user, address(0), amount);
    wrappedGho.withdrawTo(to, amount);

    // underlying
    assertEq(
      underlyingToken.balanceOf(user),
      senderBalanceBefore,
      'wrong underlying sender balance'
    );
    assertEq(
      underlyingToken.balanceOf(to),
      toBalanceBefore + amount,
      'wrong underlying to balance'
    );
    assertEq(
      underlyingToken.balanceOf(address(wrappedGho)),
      wrapperBalanceBefore - amount,
      'wrong underlying wrapper balance'
    );
    // wrapped
    assertEq(
      wrappedGho.balanceOf(user),
      senderWBalanceBefore - amount,
      'wrong wrapper sender balance'
    );
    assertEq(wrappedGho.balanceOf(to), toWBalanceBefore, 'wrong wrapper to balance');
    assertEq(wrappedGho.totalSupply(), totalSupplyBefore - amount, 'wrong wrapper totalSupply');

    vm.stopPrank();
  }

  function test_permit_success(
    uint256 userPk,
    address sender,
    address spender,
    uint256 amount
  ) public {
    address user;
    vm.assume(
      userPk != 0 &&
        userPk < 115792089237316195423570985008687907852837564279074904382605163141518161494337 && // < curve order
        (user = vm.addr(userPk)) != sender &&
        !_isEitherAddressZeroOrWrappedGho(sender) &&
        !_isEitherAddressZeroOrWrappedGho(spender) &&
        sender != address(_getProxyAdmin(address(wrappedGho)))
    );

    uint256 deadline = vm.getBlockTimestamp() + 1;
    bytes32 digest = sigUtils.getTypedDataHash(
      SigUtils.Permit({owner: user, spender: spender, value: amount, nonce: 0, deadline: deadline})
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    uint256 allowanceBefore = wrappedGho.allowance(user, spender);

    vm.prank(sender);
    vm.expectEmit(address(wrappedGho));
    emit Approval(user, spender, amount);
    wrappedGho.permit(user, spender, amount, deadline, v, r, s);

    assertEq(wrappedGho.allowance(user, spender), allowanceBefore + amount, 'wrong user allowance');
  }

  function test_transfer_success(address sender, address receiver, uint256 amount) public {
    vm.assume(
      sender != receiver &&
        !_isEitherAddressZeroOrWrappedGho(sender) &&
        !_isEitherAddressZeroOrWrappedGho(receiver) &&
        sender != address(_getProxyAdmin(address(wrappedGho)))
    );
    deal(address(wrappedGho), sender, amount);

    uint256 senderWBalanceBefore = wrappedGho.balanceOf(sender);
    uint256 receiverWBalanceBefore = wrappedGho.balanceOf(receiver);

    vm.expectEmit(address(wrappedGho));
    emit Transfer(sender, receiver, amount);
    vm.prank(sender);
    wrappedGho.transfer(receiver, amount);

    assertEq(
      wrappedGho.balanceOf(sender),
      senderWBalanceBefore - amount,
      'wrong wrapper sender balance'
    );
    assertEq(
      wrappedGho.balanceOf(receiver),
      receiverWBalanceBefore + amount,
      'wrong wrapper receiver balance'
    );
  }

  function test_transfer_from_success(
    address sender,
    address spender,
    address receiver,
    uint256 amount
  ) public {
    vm.assume(
      sender != receiver &&
        !_isEitherAddressZeroOrWrappedGho(sender) &&
        !_isEitherAddressZeroOrWrappedGho(receiver) &&
        !_isEitherAddressZeroOrWrappedGho(spender) &&
        sender != address(_getProxyAdmin(address(wrappedGho))) && // for approve
        spender != address(_getProxyAdmin(address(wrappedGho)))
    );

    deal(address(wrappedGho), sender, amount);
    vm.prank(sender);
    wrappedGho.approve(spender, amount);

    uint256 senderWBalanceBefore = wrappedGho.balanceOf(sender);
    uint256 receiverWBalanceBefore = wrappedGho.balanceOf(receiver);

    vm.expectEmit(address(wrappedGho));
    emit Transfer(sender, receiver, amount);
    vm.prank(spender);
    wrappedGho.transferFrom(sender, receiver, amount);

    assertEq(
      wrappedGho.balanceOf(sender),
      senderWBalanceBefore - amount,
      'wrong wrapper sender balance'
    );
    assertEq(
      wrappedGho.balanceOf(receiver),
      receiverWBalanceBefore + amount,
      'wrong wrapper receiver balance'
    );
  }
}
