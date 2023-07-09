// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author The Stoa Corporation Ltd.
    @title  Partner Facet
    @notice Custom functions to enable integration wit certain vaults.
    @dev    Functions are organised as (k, v) mappings, where the vault is the key.
            Motivation in doing so is to avoid a look-up implementation and trigger
            the function directly.
            One caveat of calling via the low-level 'call()' operation, passing
            the bytes4 function selector, is that functions must be accessible
            externally. Therefore, to prevent external calls, a modifier 
            "EXTGuard" has been implemented.
 */

import { Modifiers, DerivParams } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibVault } from '../libs/LibVault.sol';
import { IERC4626 } from '.././interfaces/IERC4626.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import ".././interfaces/beefy/ISwap.sol";

contract PartnerFacet is Modifiers {

    /*//////////////////////////////////////////////////////////////
                            BEEFY HOP VAULT
    //////////////////////////////////////////////////////////////*/

    function toDeriv_BeefyHop(
        address fiAsset,
        uint256 amount
    ) public EXTGuard {

        SafeERC20.safeApprove(
            IERC20(s.underlying[fiAsset]),   // Approve USDC spend.
            s.derivParams[s.vault[fiAsset]].spender,
            amount
        );

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        s.RETURN_ASSETS = ISwap(s.derivParams[s.vault[fiAsset]].spender).addLiquidity(
            amounts,
            0,
            block.timestamp + 7 days
        );
    }

    function toUnderlying_BeefyHop(
        address fiAsset,
        uint256 amount
    ) public EXTGuard {

        SafeERC20.safeApprove(
            IERC20(IERC4626(s.vault[fiAsset]).asset()),  // Approve HOP-USDC-LP spend.
            s.derivParams[s.vault[fiAsset]].spender,
            amount
        );
        s.RETURN_ASSETS = ISwap(s.derivParams[s.vault[fiAsset]].spender).removeLiquidityOneToken(
            amount,
            0,
            0,
            block.timestamp + 7 days
        );
    }

    function convertToUnderlying_BeefyHop(
        address fiAsset,
        uint256 amount
    ) public {

        s.RETURN_ASSETS = ISwap(s.derivParams[s.vault[fiAsset]].spender).calculateRemoveLiquidityOneToken(
            address(this),
            amount,
            0
        );
    }

    function convertToDeriv_BeefyHop(
        address fiAsset,
        uint256 amount
    ) public {

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LibToken._toUnderlyingDecimals(fiAsset, amount);
        s.RETURN_ASSETS = ISwap(s.derivParams[s.vault[fiAsset]].spender).calculateTokenAmount(
            address(this),
            amounts,
            false
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN - SETTERS
    //////////////////////////////////////////////////////////////*/

    function setToDeriv(
        address vault,
        string memory _toDeriv
    )   external
        onlyAdmin
        returns (bool)
    {
        s.derivParams[vault].toDeriv = bytes4(keccak256(bytes(_toDeriv)));
        return true;
    }

    function setToUnderlying(
        address vault,
        string memory _toUnderlying
    )   external
        onlyAdmin
        returns (bool)
    {
        s.derivParams[vault].toDeriv = bytes4(keccak256(bytes(_toUnderlying)));
        return true;
    }

    function setConvertToDeriv(
        address vault,
        string memory _convertToDeriv
    )   external
        onlyAdmin
        returns (bool)
    {
        s.derivParams[vault].toDeriv = bytes4(keccak256(bytes(_convertToDeriv)));
        return true;
    }

    function setConvertToUnderlying(
        address vault,
        string memory _convertToUnderlying
    )   external
        onlyAdmin
        returns (bool)
    {
        s.derivParams[vault].toDeriv = bytes4(keccak256(bytes(_convertToUnderlying)));
        return true;
    }

    function setAdd(
        address vault,
        address[] memory _add
    )   external
        onlyAdmin
        returns (bool)
    {
        s.derivParams[vault].add = _add;
        return true;
    }

    function setNum(
        address vault,
        uint256[] memory _num
    )   external
        onlyAdmin
        returns (bool)
    {
        s.derivParams[vault].num = _num;
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function getDerivParams(
        address vault
    )   external
        view
        returns (DerivParams memory)
    {
        return s.derivParams[vault];
    }
}