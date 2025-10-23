// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/PythStructs.sol";

/**
 * @title PriceMath
 * @dev Library for price calculations and normalization with Pyth integration
 */
library PriceMath {
    // ============ CONSTANTS ============
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    int256 public constant MAX_EXPONENT = 18;
    int256 public constant MIN_EXPONENT = -18;
    
    // ============ ERRORS ============
    error InvalidPrice();
    error InvalidExponent();
    error DivisionByZero();
    error Overflow();
    error Underflow();
    error InvalidPriceData();

    // ============ PRICE NORMALIZATION ============
    
    /**
     * @dev Normalize a Pyth price to 1e18 precision
     * @param price The price from Pyth (int64)
     * @param expo The exponent from Pyth (int32)
     * @return normalizedPrice The normalized price with 1e18 precision
     */
    function normalizePrice(int64 price, int32 expo) internal pure returns (uint256 normalizedPrice) {
        if (price <= 0) revert InvalidPrice();
        if (int256(expo) < MIN_EXPONENT || int256(expo) > MAX_EXPONENT) revert InvalidExponent();
        
        // Convert to uint256 for calculations
        uint256 absPrice = uint256(uint64(price));
        int256 adjustedExpo = int256(expo) + 18; // Adjust for 1e18 precision
        
        if (adjustedExpo >= 0) {
            // Positive exponent: multiply by 10^expo
            if (adjustedExpo > 255) revert Overflow();
            normalizedPrice = absPrice * (10 ** uint256(adjustedExpo));
        } else {
            // Negative exponent: divide by 10^(-expo)
            if (adjustedExpo < -255) revert Underflow();
            uint256 divisor = 10 ** uint256(-adjustedExpo);
            normalizedPrice = absPrice / divisor;
        }
        
        // Check for overflow
        if (normalizedPrice == 0 && absPrice > 0) revert Underflow();
    }

    /**
     * @dev Normalize a Pyth Price struct to 1e18 precision
     * @param pythPrice The Pyth Price struct
     * @return normalizedPrice The normalized price with 1e18 precision
     */
    function normalizePythPrice(PythStructs.Price memory pythPrice) internal pure returns (uint256 normalizedPrice) {
        return normalizePrice(pythPrice.price, pythPrice.expo);
    }

    /**
     * @dev Normalize a price with custom precision
     * @param price The price value
     * @param expo The exponent
     * @param targetPrecision The target precision (e.g., 1e18, 1e6)
     * @return normalizedPrice The normalized price with target precision
     */
    function normalizePriceToPrecision(
        int64 price,
        int32 expo,
        uint256 targetPrecision
    ) internal pure returns (uint256 normalizedPrice) {
        if (price <= 0) revert InvalidPrice();
        if (int256(expo) < MIN_EXPONENT || int256(expo) > MAX_EXPONENT) revert InvalidExponent();
        if (targetPrecision == 0) revert DivisionByZero();
        
        uint256 absPrice = uint256(uint64(price));
        int256 adjustedExpo = int256(expo) + int256(_getExponent(targetPrecision));
        
        if (adjustedExpo >= 0) {
            if (adjustedExpo > 255) revert Overflow();
            normalizedPrice = absPrice * (10 ** uint256(adjustedExpo));
        } else {
            if (adjustedExpo < -255) revert Underflow();
            uint256 divisor = 10 ** uint256(-adjustedExpo);
            normalizedPrice = absPrice / divisor;
        }
        
        if (normalizedPrice == 0 && absPrice > 0) revert Underflow();
    }

    // ============ DRAWDOWN CALCULATIONS ============
    
    /**
     * @dev Calculate drawdown in basis points
     * @param currentPrice The current price (normalized to 1e18)
     * @param previousPrice The previous price (normalized to 1e18)
     * @return drawdownBps The drawdown in basis points (0-10000)
     */
    function calculateDrawdownBps(
        uint256 currentPrice,
        uint256 previousPrice
    ) internal pure returns (uint256 drawdownBps) {
        if (previousPrice == 0) revert DivisionByZero();
        if (currentPrice > previousPrice) return 0; // No drawdown if price increased
        
        // Calculate drawdown percentage
        uint256 drawdown = ((previousPrice - currentPrice) * BASIS_POINTS) / previousPrice;
        
        // Ensure drawdown doesn't exceed 100%
        return drawdown > BASIS_POINTS ? BASIS_POINTS : drawdown;
    }

    /**
     * @dev Calculate drawdown percentage (0-100)
     * @param currentPrice The current price (normalized to 1e18)
     * @param previousPrice The previous price (normalized to 1e18)
     * @return drawdownPercent The drawdown percentage (0-100)
     */
    function calculateDrawdownPercent(
        uint256 currentPrice,
        uint256 previousPrice
    ) internal pure returns (uint256 drawdownPercent) {
        return calculateDrawdownBps(currentPrice, previousPrice) / 100;
    }

    /**
     * @dev Calculate drawdown from Pyth prices
     * @param currentPythPrice The current Pyth price
     * @param previousPythPrice The previous Pyth price
     * @return drawdownBps The drawdown in basis points
     */
    function calculateDrawdownFromPyth(
        PythStructs.Price memory currentPythPrice,
        PythStructs.Price memory previousPythPrice
    ) internal pure returns (uint256 drawdownBps) {
        uint256 currentNormalized = normalizePythPrice(currentPythPrice);
        uint256 previousNormalized = normalizePythPrice(previousPythPrice);
        
        return calculateDrawdownBps(currentNormalized, previousNormalized);
    }

    // ============ PRICE COMPARISON ============
    
    /**
     * @dev Check if price has dropped below threshold
     * @param currentPrice The current price (normalized to 1e18)
     * @param previousPrice The previous price (normalized to 1e18)
     * @param thresholdBps The threshold in basis points (e.g., 1000 = 10%)
     * @return isBelowThreshold True if price dropped below threshold
     */
    function isPriceBelowThreshold(
        uint256 currentPrice,
        uint256 previousPrice,
        uint256 thresholdBps
    ) internal pure returns (bool isBelowThreshold) {
        if (thresholdBps > BASIS_POINTS) revert InvalidPrice();
        
        uint256 drawdownBps = calculateDrawdownBps(currentPrice, previousPrice);
        return drawdownBps >= thresholdBps;
    }

    /**
     * @dev Calculate price change percentage
     * @param currentPrice The current price (normalized to 1e18)
     * @param previousPrice The previous price (normalized to 1e18)
     * @return changeBps The price change in basis points (can be negative)
     */
    function calculatePriceChangeBps(
        uint256 currentPrice,
        uint256 previousPrice
    ) internal pure returns (int256 changeBps) {
        if (previousPrice == 0) revert DivisionByZero();
        
        if (currentPrice >= previousPrice) {
            // Price increased
            uint256 increase = ((currentPrice - previousPrice) * BASIS_POINTS) / previousPrice;
            return int256(increase);
        } else {
            // Price decreased
            uint256 decrease = ((previousPrice - currentPrice) * BASIS_POINTS) / previousPrice;
            return -int256(decrease);
        }
    }

    // ============ PRICE VALIDATION ============
    
    /**
     * @dev Validate Pyth price data
     * @param pythPrice The Pyth price to validate
     * @param maxAge Maximum age in seconds
     * @return isValid True if price is valid
     */
    function validatePythPrice(
        PythStructs.Price memory pythPrice,
        uint256 maxAge
    ) internal view returns (bool isValid) {
        // Check if price is positive
        if (pythPrice.price <= 0) return false;
        
        // Check if exponent is within valid range
        if (int256(pythPrice.expo) < MIN_EXPONENT || int256(pythPrice.expo) > MAX_EXPONENT) return false;
        
        // Check if price is not too old
        if (block.timestamp - pythPrice.publishTime > maxAge) return false;
        
        // Check if confidence is reasonable (not zero)
        if (pythPrice.conf == 0) return false;
        
        return true;
    }

    /**
     * @dev Check if price is stale
     * @param pythPrice The Pyth price to check
     * @param maxAge Maximum age in seconds
     * @return isStale True if price is stale
     */
    function isPriceStale(
        PythStructs.Price memory pythPrice,
        uint256 maxAge
    ) internal view returns (bool isStale) {
        return block.timestamp - pythPrice.publishTime > maxAge;
    }

    // ============ UTILITY FUNCTIONS ============
    
    /**
     * @dev Get the exponent of a precision value
     * @param precision The precision value (e.g., 1e18, 1e6)
     * @return exponent The exponent (e.g., 18, 6)
     */
    function _getExponent(uint256 precision) private pure returns (uint256 exponent) {
        if (precision == 0) return 0;
        
        uint256 temp = precision;
        exponent = 0;
        
        while (temp % 10 == 0) {
            temp /= 10;
            exponent++;
        }
        
        // Check if precision is a valid power of 10
        if (temp != 1) revert InvalidPrice();
        
        return exponent;
    }

    /**
     * @dev Convert basis points to percentage
     * @param bps The basis points
     * @return percent The percentage (0-100)
     */
    function bpsToPercent(uint256 bps) internal pure returns (uint256 percent) {
        return bps / 100;
    }

    /**
     * @dev Convert percentage to basis points
     * @param percent The percentage (0-100)
     * @return bps The basis points
     */
    function percentToBps(uint256 percent) internal pure returns (uint256 bps) {
        return percent * 100;
    }

    /**
     * @dev Calculate the minimum price for a given drawdown threshold
     * @param referencePrice The reference price (normalized to 1e18)
     * @param maxDrawdownBps The maximum drawdown in basis points
     * @return minPrice The minimum price before threshold is breached
     */
    function calculateMinPrice(
        uint256 referencePrice,
        uint256 maxDrawdownBps
    ) internal pure returns (uint256 minPrice) {
        if (maxDrawdownBps > BASIS_POINTS) revert InvalidPrice();
        
        uint256 drawdownAmount = (referencePrice * maxDrawdownBps) / BASIS_POINTS;
        return referencePrice - drawdownAmount;
    }

    /**
     * @dev Calculate the maximum price for a given drawdown threshold
     * @param referencePrice The reference price (normalized to 1e18)
     * @param maxDrawdownBps The maximum drawdown in basis points
     * @return maxPrice The maximum price before threshold is breached
     */
    function calculateMaxPrice(
        uint256 referencePrice,
        uint256 maxDrawdownBps
    ) internal pure returns (uint256 maxPrice) {
        if (maxDrawdownBps > BASIS_POINTS) revert InvalidPrice();
        
        uint256 increaseAmount = (referencePrice * maxDrawdownBps) / BASIS_POINTS;
        return referencePrice + increaseAmount;
    }

    // ============ PRICE AGGREGATION ============
    
    /**
     * @dev Calculate weighted average price
     * @param prices Array of normalized prices
     * @param weights Array of weights (must sum to 1e18)
     * @return weightedAverage The weighted average price
     */
    function calculateWeightedAverage(
        uint256[] memory prices,
        uint256[] memory weights
    ) internal pure returns (uint256 weightedAverage) {
        if (prices.length != weights.length) revert InvalidPrice();
        if (prices.length == 0) revert InvalidPrice();
        
        uint256 totalWeight = 0;
        uint256 weightedSum = 0;
        
        for (uint256 i = 0; i < prices.length; i++) {
            totalWeight += weights[i];
            weightedSum += (prices[i] * weights[i]) / PRECISION;
        }
        
        if (totalWeight != PRECISION) revert InvalidPrice();
        
        return weightedSum;
    }

    /**
     * @dev Calculate simple average price
     * @param prices Array of normalized prices
     * @return average The average price
     */
    function calculateAverage(uint256[] memory prices) internal pure returns (uint256 average) {
        if (prices.length == 0) revert InvalidPrice();
        
        uint256 sum = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            sum += prices[i];
        }
        
        return sum / prices.length;
    }
}
