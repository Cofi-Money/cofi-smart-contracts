// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from "../libs/LibERC20Storage.sol";
import { LibERC20Token } from '../libs/LibERC20Token.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Access Facet
    @notice Admin functions for managing/viewing account roles.
 */

contract TokenAccessFacet is Modifiers {

    /*//////////////////////////////////////////////////////////////
                            ADMIN - SETTERS
    //////////////////////////////////////////////////////////////*/

    function setAdmin(address _account, uint8 _enabled) external onlyAuthorized returns (bool) {
        s.admin[_account] = _enabled;

        return true;
    }

    /**
     * @dev     If freezing, first ensure account is opted out of rebases.
     * @return  bool Indicating true if frozen.
     */
    function setFrozen(address _account, uint8 _enabled) external onlyAuthorized returns (bool) {
        require(
            !LibERC20Token._isNonRebasingAccount(_account),
            'AccessFacet: Account must be opted out before freezing'
        );
        s.frozen[_account] = _enabled;

        return true;
    }

    function setPaused(uint8 _enabled) external onlyAuthorized returns (bool) {
        s.paused = _enabled;

        return true;
    }

    function setRebaseLock(address _account, uint8 _enabled) external onlyAuthorized returns (bool) {
        s.rebaseLock[_account] = _enabled;

        return true;
    }

    function setApp(address _app) external onlyAuthorized {
        s.app = _app;
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getAdminStatus(address _account) external view returns (uint8) {
        return s.admin[_account];
    }

    function getFrozenStatus(address _account) external view returns (uint8) {
        return s.frozen[_account];
    }

    function getRebaseLoclStatus(address _account) external view returns (uint8) {
        return s.rebaseLock[_account];
    }

    function getPausedStatus() external view returns (uint8) {
        return s.paused;
    }

    function getApp() external view returns (address) {
        return s.app;
    }
}