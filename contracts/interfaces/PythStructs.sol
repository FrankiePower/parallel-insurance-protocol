// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library PythStructs {
    struct Price {
        int64 price;
        uint64 conf;
        int32 expo;
        uint256 publishTime;
    }

    struct PriceFeed {
        bytes32 id;
        uint8 priceType;
        uint8 status;
        uint8 numPublishers;
        uint8 maxNumPublishers;
        uint64 attestationTime;
        uint64 publishTime;
        uint64 prevPublishTime;
        int64 price;
        uint64 conf;
        int32 expo;
        int64 prevPrice;
        uint64 prevConf;
        int32 prevExpo;
    }

    struct PriceInfo {
        uint256 price;
        uint256 conf;
        int32 expo;
        int64 priceRaw;
        uint64 confRaw;
        int32 expoRaw;
        uint256 publishTime;
    }
}
