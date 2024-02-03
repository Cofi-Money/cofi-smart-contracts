// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICOFIMoney {

    function rebase(address _cofi) external returns (uint256, uint256, uint256);
}

interface ICOFIRebasingToken {

    function rebasingCreditsPerToken() external view returns (uint256);
}

contract Helper {

    mapping(address => uint256[]) public rcpt;

    mapping(address => uint8) admin;

    mapping(address => uint8) upkeep;

    ICOFIMoney app;

    constructor(
        address _app,
        address _coUSD,
        address _coETH,
        address _coBTC
    ) {
        app = ICOFIMoney(_app);
        rcpt[_coUSD].push(1e9);
        rcpt[_coETH].push(1e9);
        rcpt[_coBTC].push(1e9);
        admin[msg.sender] = 1;
        upkeep[msg.sender] = 1;
    }

    /**
     * @notice Performs rebase and stores rcpt value for APY calc.
     */
    function rebase(
        address _cofi
    )   external
        onlyUpkeep
        returns (bool)
    {
        app.rebase(_cofi);
        rcpt[_cofi].push(ICOFIRebasingToken(_cofi).rebasingCreditsPerToken());
        return true;
    }

    /**
     * @notice Used for APY calculation off-chain: (rcptA / rcptB)^(365.25 / period) - 1.
     * @param _cofi     The cofi token to enquire for.
     * @param _period   The number of days to retrieve annualized APY for.
     */
    function getRebasingCreditsPerToken(
        address _cofi,
        uint256 _period
    )   external view
        returns (uint256 rcptA, uint256 rcptB)
    {
        rcptA = rcpt[_cofi].length < _period ?
            1e9 :
            rcpt[_cofi][rcpt[_cofi].length - _period];
        rcptB = rcpt[_cofi][rcpt[_cofi].length - 1];
    }

    /**
     * @notice Enables admin to manually set rcpt.
     */
    function setRebasingCreditsPerToken(
        address             _cofi,
        uint256[] calldata  _rcpt
    )   external
        onlyAdmin
        returns (bool)
    {
        rcpt[_cofi] = _rcpt;
        return true;
    }

    /**
     * @notice Enables admin to manually add rcpt entry.
     */
    function pushRebasingCreditsPerToken(
        address _cofi,
        uint256 _rcpt
    )   external
        onlyAdmin
        returns (bool)
    {
        rcpt[_cofi].push(_rcpt);
        return true;
    }

    function setUpkeep(
        address _account,
        uint8   _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        upkeep[_account] = _enabled;
        return true;
    }

    function setAdmin(
        address _account,
        uint8   _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        admin[_account] = _enabled;
        return true;
    }

    modifier onlyAdmin() {
        require(admin[msg.sender] == 1, "Caller not admin");
        _;
    }

    modifier onlyUpkeep() {
        require(upkeep[msg.sender] == 1, "Caller not upkeep");
        _;
    }
}