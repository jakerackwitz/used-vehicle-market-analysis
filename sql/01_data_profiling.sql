-- ============================================================
-- USED VEHICLE MARKET ANALYSIS
-- 01 - DATA PROFILING
-- ============================================================
-- Purpose:
-- Inspect the raw Craigslist listings, assess completeness, identify unusual prices,
-- and investigate possible non-sale advertisements and duplicate IDs.
--
-- Database: data_analytics_portfolio
-- Schema:   used_cars
-- Raw table: used_cars.vehicles_raw
-- Clean view: used_cars.vehicles_clean
--
-- ============================================================

-- ===================
-- 1. DATA PROFILING
-- ===================

-- Inspect a small sample of raw records and their original field values.
SELECT *
FROM used_cars.vehicles_raw
LIMIT 5;

-- Measure dataset size, ID uniqueness, and missing IDs.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT id) AS unique_vehicles,
    COUNT(*) - COUNT(id) AS missing_ids
FROM used_cars.vehicles_raw;

-- Count missing or blank values in important analytical fields.
SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(price), '') IS NULL) AS missing_price,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(year), '') IS NULL) AS missing_year,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(manufacturer), '') IS NULL) AS missing_manufacturer,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(model), '') IS NULL) AS missing_model,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(condition), '') IS NULL) AS missing_condition,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(odometer), '') IS NULL) AS missing_odometer,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(fuel), '') IS NULL) AS missing_fuel,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(transmission), '') IS NULL) AS missing_transmission,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(state), '') IS NULL) AS missing_state
FROM used_cars.vehicles_raw;

-- Summarize the raw distribution of reported vehicle conditions.
SELECT
    condition,
    COUNT(*) AS vehicle_count
FROM used_cars.vehicles_raw
GROUP BY condition
ORDER BY vehicle_count DESC;

-- Compare missing condition information across seller types.
SELECT
    seller_type,
    COUNT(*) AS total_vehicles,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(condition), '') IS NULL
    ) AS missing_condition,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE NULLIF(TRIM(condition), '') IS NULL
        ) / COUNT(*), 2
    ) AS missing_percentage
FROM used_cars.vehicles_raw
GROUP BY seller_type
ORDER BY missing_percentage DESC;

-- Show condition completeness by seller type, including a Missing category.
SELECT
    seller_type,
    COALESCE(
        NULLIF(TRIM(condition), ''),
        'Missing'
    ) AS condition,
    COUNT(*) AS vehicle_count,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (
            PARTITION BY seller_type
        ), 2
    ) AS percentage
FROM used_cars.vehicles_raw
GROUP BY
    seller_type,
    COALESCE(
        NULLIF(TRIM(condition), ''),
        'Missing'
    )
ORDER BY
    seller_type,
    vehicle_count DESC;

-- Compare raw asking-price statistics by seller type where price is numeric.
SELECT
    seller_type,
    COUNT(*) AS vehicle_count,
    ROUND(AVG(price::NUMERIC), 2) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY price::NUMERIC)::NUMERIC,
        2
    ) AS median_price,
    MIN(price::NUMERIC) AS minimum_price,
    MAX(price::NUMERIC) AS maximum_price
FROM used_cars.vehicles_raw
WHERE price ~ '^[0-9]+(\.[0-9]+)?$'
GROUP BY seller_type;

-- Inspect the highest numeric asking prices for potential anomalies.
SELECT
    id,
    price,
    year,
    manufacturer,
    model,
    seller_type,
    state
FROM used_cars.vehicles_raw
WHERE price ~ '^[0-9]+$'
ORDER BY price::NUMERIC DESC
LIMIT 25;

-- Quantify listings priced above $100,000.
SELECT
    COUNT(*) AS total_listings,
    COUNT(*) FILTER (
        WHERE price::NUMERIC > 100000
    ) AS listings_over_100k,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE price::NUMERIC > 100000
        ) / COUNT(*),
        2
    ) AS percentage_over_100k
FROM used_cars.vehicles_raw
WHERE price ~ '^[0-9]+$';

-- Group raw listings into asking-price ranges.
SELECT
    CASE
        WHEN price::NUMERIC = 0 THEN '$0'
        WHEN price::NUMERIC <= 5000 THEN '$1–$5,000'
        WHEN price::NUMERIC <= 10000 THEN '$5,001–$10,000'
        WHEN price::NUMERIC <= 20000 THEN '$10,001–$20,000'
        WHEN price::NUMERIC <= 30000 THEN '$20,001–$30,000'
        WHEN price::NUMERIC <= 50000 THEN '$30,001–$50,000'
        WHEN price::NUMERIC <= 100000 THEN '$50,001–$100,000'
        ELSE 'Over $100,000'
    END AS price_range,
    COUNT(*) AS listing_count
FROM used_cars.vehicles_raw
WHERE price ~ '^[0-9]+$'
GROUP BY 1
ORDER BY MIN(price::NUMERIC);

-- Inspect examples of zero-price listings.
-- Inspect listings above the $100,000 primary analysis threshold.
SELECT
    id,
    price,
    year,
    manufacturer,
    model,
    condition,
    seller_type,
    state,
    title
FROM used_cars.vehicles_raw
WHERE price::NUMERIC = 0
LIMIT 25;

-- Measure zero-price listing rates by seller type.
SELECT
    seller_type,
    COUNT(*) AS total_listings,
    COUNT(*) FILTER (
        WHERE price::NUMERIC = 0
    ) AS zero_price_listings,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE price::NUMERIC = 0
        ) / COUNT(*),
        2
    ) AS zero_price_percentage
FROM used_cars.vehicles_raw
GROUP BY seller_type
ORDER BY zero_price_percentage DESC;

-- Check extreme-price listings by seller type.
SELECT
    seller_type,
    COUNT(*) FILTER (
        WHERE price::NUMERIC > 250000
    ) AS listings_over_250k,
    COUNT(*) AS total_listings,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE price::NUMERIC > 250000
        ) / COUNT(*),
        3
    ) AS percentage_over_250k
FROM used_cars.vehicles_raw
GROUP BY seller_type
ORDER BY listings_over_250k DESC;

SELECT
    id,
    price,
    year,
    manufacturer,
    model,
    condition,
    seller_type,
    state,
    title
FROM used_cars.vehicles_raw
WHERE price::NUMERIC > 100000
ORDER BY price::NUMERIC DESC
LIMIT 25;

-- Check extreme prices for repeated-digit and sequential-digit patterns.
SELECT
    COUNT(*) AS total_extreme_listings,
    COUNT(*) FILTER (
        WHERE price ~ '^([0-9])\1+$'
    ) AS repeated_digit_prices,
    COUNT(*) FILTER (
        WHERE price IN (
            '12345678',
            '123456789',
            '1234567890',
            '987654321',
            '9876543210'
        )
    ) AS sequential_digit_prices
FROM used_cars.vehicles_raw
WHERE price::NUMERIC > 100000;

-- Search listing titles for language suggesting wanted or vehicle-buying advertisements.
SELECT
    id,
    price,
    year,
    manufacturer,
    model,
    seller_type,
    state,
    title
FROM used_cars.vehicles_raw
WHERE
    LOWER(title) LIKE '%wanted%'
    OR LOWER(title) LIKE '%looking for%'
    OR LOWER(title) LIKE '%buying%'
    OR LOWER(title) LIKE '%cash for cars%'
ORDER BY price::NUMERIC DESC
LIMIT 30;

-- Estimate how many raw records may be non-sale advertisements based on title wording.
SELECT
    COUNT(*) AS total_listings,
    COUNT(*) FILTER (
        WHERE LOWER(title) ~
        '(wanted|looking for|buying|we buy|cash for cars)'
    ) AS potential_non_sale_listings
FROM used_cars.vehicles_raw;

-- Check whether any IDs occur more than once in the raw table.
SELECT
    id,
    COUNT(*) AS record_count
FROM used_cars.vehicles_raw
GROUP BY id
HAVING COUNT(*) > 1
ORDER BY record_count DESC
LIMIT 20;
