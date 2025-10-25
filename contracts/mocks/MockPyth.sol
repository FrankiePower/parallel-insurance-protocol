// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IPyth.sol";
import "../interfaces/PythStructs.sol";

/**
 * @title MockPyth
 * @dev Mock implementation of Pyth for testing purposes
 */
contract MockPyth is IPyth {
    mapping(bytes32 => PythStructs.Price) private prices;
    mapping(bytes32 => PythStructs.PriceFeed) private priceFeeds;
    
    uint32 public constant VALID_TIME_PERIOD = 3600; // 1 hour
    
    event PriceUpdated(bytes32 indexed priceId, int64 price, uint64 conf, int32 expo, uint256 publishTime);

    function updatePriceFeeds(bytes[] calldata updateData) external payable override {
        // Mock implementation - in real scenario would parse updateData
        emit PriceUpdated(bytes32(0), 0, 0, 0, block.timestamp);
    }

    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable override {
        // Mock implementation
        for (uint256 i = 0; i < priceIds.length; i++) {
            emit PriceUpdated(priceIds[i], 0, 0, 0, publishTimes[i]);
        }
    }

    function getPrice(bytes32 id) external view override returns (PythStructs.Price memory price) {
        price = prices[id];
        require(price.publishTime > 0, "Price not found");
        return price;
    }

    function getPriceUnsafe(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getPriceNoOlderThan(
        bytes32 id,
        uint256 age
    ) external view override returns (PythStructs.Price memory price) {
        price = prices[id];
        require(price.publishTime > 0, "Price not found");
        require(block.timestamp - price.publishTime <= age, "Price too old");
        return price;
    }

    function getEmaPrice(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return prices[id]; // Mock implementation - same as regular price
    }

    function getEmaPriceUnsafe(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getEmaPriceNoOlderThan(
        bytes32 id,
        uint256 age
    ) external view override returns (PythStructs.Price memory price) {
        price = prices[id];
        require(price.publishTime > 0, "Price not found");
        require(block.timestamp - price.publishTime <= age, "Price too old");
        return price;
    }

    function getPriceFeed(bytes32 id) external view override returns (PythStructs.PriceFeed memory priceFeed) {
        return priceFeeds[id];
    }

    function getPriceFeedUnsafe(bytes32 id) external view override returns (PythStructs.PriceFeed memory priceFeed) {
        return priceFeeds[id];
    }

    function getPriceFeedNoOlderThan(
        bytes32 id,
        uint256 age
    ) external view override returns (PythStructs.PriceFeed memory priceFeed) {
        priceFeed = priceFeeds[id];
        require(priceFeed.publishTime > 0, "Price feed not found");
        require(block.timestamp - priceFeed.publishTime <= age, "Price feed too old");
        return priceFeed;
    }

    function getUpdateFee(bytes[] calldata updateData) external pure override returns (uint256 fee) {
        return 0.1 ether; // Mock fee
    }

    function getUpdateFee(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external pure override returns (uint256 fee) {
        return 0.1 ether; // Mock fee
    }

    function getValidTimePeriod() external pure override returns (uint32 validTimePeriod) {
        return VALID_TIME_PERIOD;
    }

    function getPriceIdFromBytes32(bytes32 priceId) external pure override returns (bytes32) {
        return priceId;
    }

    function getBytes32FromPriceId(bytes32 priceId) external pure override returns (bytes32) {
        return priceId;
    }

    // Mock functions for testing
    function setPrice(
        bytes32 priceId,
        int64 price,
        uint64 conf,
        int32 expo,
        uint256 publishTime
    ) external {
        prices[priceId] = PythStructs.Price({
            price: price,
            conf: conf,
            expo: expo,
            publishTime: publishTime
        });
        
        emit PriceUpdated(priceId, price, conf, expo, publishTime);
    }

    function setPriceFeed(
        bytes32 priceId,
        uint8 priceType,
        uint8 status,
        uint8 numPublishers,
        uint8 maxNumPublishers,
        uint64 attestationTime,
        uint64 publishTime,
        uint64 prevPublishTime,
        int64 price,
        uint64 conf,
        int32 expo,
        int64 prevPrice,
        uint64 prevConf,
        int32 prevExpo
    ) external {
        priceFeeds[priceId] = PythStructs.PriceFeed({
            id: priceId,
            priceType: priceType,
            status: status,
            numPublishers: numPublishers,
            maxNumPublishers: maxNumPublishers,
            attestationTime: attestationTime,
            publishTime: publishTime,
            prevPublishTime: prevPublishTime,
            price: price,
            conf: conf,
            expo: expo,
            prevPrice: prevPrice,
            prevConf: prevConf,
            prevExpo: prevExpo
        });
    }
}
