// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PythStructs.sol";

interface IPyth {
    function updatePriceFeeds(bytes[] calldata updateData) external payable;
    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable;
    function getPrice(bytes32 id) external view returns (PythStructs.Price memory price);
    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);
    function getPriceNoOlderThan(
        bytes32 id,
        uint256 age
    ) external view returns (PythStructs.Price memory price);
    function getEmaPrice(bytes32 id) external view returns (PythStructs.Price memory price);
    function getEmaPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);
    function getEmaPriceNoOlderThan(
        bytes32 id,
        uint256 age
    ) external view returns (PythStructs.Price memory price);
    function getPriceFeed(bytes32 id) external view returns (PythStructs.PriceFeed memory priceFeed);
    function getPriceFeedUnsafe(bytes32 id) external view returns (PythStructs.PriceFeed memory priceFeed);
    function getPriceFeedNoOlderThan(
        bytes32 id,
        uint256 age
    ) external view returns (PythStructs.PriceFeed memory priceFeed);
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint256 fee);
    function getUpdateFee(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external view returns (uint256 fee);
    function getValidTimePeriod() external view returns (uint32 validTimePeriod);
    function getPriceIdFromBytes32(bytes32 priceId) external view returns (bytes32);
    function getBytes32FromPriceId(bytes32 priceId) external view returns (bytes32);
}
