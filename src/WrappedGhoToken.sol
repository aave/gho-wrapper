// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20WrapperUpgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20WrapperUpgradeable.sol';
import {ERC20PermitUpgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import {ERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title WrappedGhoToken
 * @author Aave Labs
 * @notice Wrapper contract for the GHO Token
 */
contract WrappedGhoToken is ERC20WrapperUpgradeable, ERC20PermitUpgradeable {
  /**
   * @dev Constructor
   */
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initialize
   * @param underlyingToken_ The address of the underlying token
   * @param name_ The name of the token
   * @param symbol_ The symbol of the token
   */
  function initialize(
    IERC20 underlyingToken_,
    string memory name_,
    string memory symbol_
  ) external initializer {
    __ERC20_init(name_, symbol_);
    __ERC20Wrapper_init(underlyingToken_);
    __ERC20Permit_init(name_);
  }

  /// @inheritdoc ERC20Upgradeable
  function decimals()
    public
    view
    override(ERC20Upgradeable, ERC20WrapperUpgradeable)
    returns (uint8)
  {
    return super.decimals();
  }
}
