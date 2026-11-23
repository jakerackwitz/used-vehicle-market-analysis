-- ============================================================
-- USED VEHICLE MARKET ANALYSIS
-- 02 - DATA CLEANING
-- ============================================================
-- Purpose:
-- Create the standardized clean view and flag suspicious prices and
-- potential non-sale advertisements for downstream analysis.
--
-- Database: data_analytics_portfolio
-- Schema:   used_cars
-- Raw table: used_cars.vehicles_raw
-- Clean view: used_cars.vehicles_clean
--
-- Run after 01_data_profiling.sql.
-- ============================================================

CREATE OR REPLACE VIEW used_cars.vehicles_clean AS
SELECT
    id,
    NULLIF(TRIM(url), '') AS url,
    NULLIF(TRIM(region), '') AS region,
    NULLIF(TRIM(region_url), '') AS region_url,
    NULLIF(TRIM(price), '')::NUMERIC AS price,
    NULLIF(TRIM(year), '')::INTEGER AS year,
    NULLIF(TRIM(manufacturer), '') AS manufacturer,
    NULLIF(TRIM(model), '') AS model,
    NULLIF(TRIM(condition), '') AS condition,
    NULLIF(TRIM(cylinders), '') AS cylinders,
    NULLIF(TRIM(fuel), '') AS fuel,
    NULLIF(TRIM(odometer), '')::NUMERIC AS odometer,
    NULLIF(TRIM(title_status), '') AS title_status,
    NULLIF(TRIM(transmission), '') AS transmission,
    NULLIF(TRIM(vin), '') AS vin,
    NULLIF(TRIM(drive), '') AS drive,
    NULLIF(TRIM(size), '') AS size,
    NULLIF(TRIM(type), '') AS type,
    NULLIF(TRIM(paint_color), '') AS paint_color,
    NULLIF(TRIM(image_url), '') AS image_url,
    NULLIF(TRIM(description), '') AS description,
    NULLIF(TRIM(county), '') AS county,
    NULLIF(TRIM(state), '') AS state,
    NULLIF(TRIM(lat), '')::NUMERIC AS lat,
    NULLIF(TRIM(long), '')::NUMERIC AS long,
    NULLIF(TRIM(posting_date), '') AS posting_date,
    NULLIF(TRIM(seller_type), '') AS seller_type,
    NULLIF(TRIM(title), '') AS title,
    NULLIF(TRIM(updated_date), '') AS updated_date,
    NULLIF(TRIM(address_street), '') AS address_street,
    NULLIF(TRIM(address_city), '') AS address_city,
    NULLIF(TRIM(address_state), '') AS address_state,
    NULLIF(TRIM(address_postal_code), '') AS address_postal_code,
    NULLIF(TRIM(address_country), '') AS address_country,
    NULLIF(TRIM(image_count), '')::INTEGER AS image_count,
    NULLIF(TRIM(image_urls), '') AS image_urls,
    NULLIF(TRIM(delivery_available), '') AS delivery_available,
    NULLIF(TRIM(odometer_broken), '') AS odometer_broken,
    NULLIF(TRIM(odometer_rolled_over), '') AS odometer_rolled_over,
    NULLIF(TRIM(monthly_payment), '') AS monthly_payment,
    NULLIF(TRIM(other_attributes), '') AS other_attributes,
    -- Flag suspicious prices
    (
        price::NUMERIC > 100000
        AND (
            price ~ '^([0-9])\1+$'
            OR price IN (
                '12345678',
                '123456789',
                '1234567890',
                '987654321',
                '9876543210'
            )
            OR price::NUMERIC = 5771710
        )
    ) AS is_suspicious_price,
    -- Flag potential non-sale advertisements
    (
        LOWER(COALESCE(title, '')) ~
        '(wanted|looking for|we buy|cash for cars)'
        OR LOWER(COALESCE(model, '')) LIKE '%we buy cars%'
        OR price::NUMERIC = 5771710
    ) AS is_non_sale_listing,
    -- Combined indicator for our intended analysis
    (
        NOT (
            price::NUMERIC > 100000
            AND (
                price ~ '^([0-9])\1+$'
                OR price IN (
                    '12345678',
                    '123456789',
                    '1234567890',
                    '987654321',
                    '9876543210'
                )
                OR price::NUMERIC = 5771710
            )
        )
        AND NOT (
            LOWER(COALESCE(title, '')) ~
            '(wanted|looking for|we buy|cash for cars)'
            OR LOWER(COALESCE(model, '')) LIKE '%we buy cars%'
            OR price::NUMERIC = 5771710
        )
    ) AS is_valid_vehicle_listing
FROM used_cars.vehicles_raw
WHERE NULLIF(TRIM(price), '')::NUMERIC > 0;

SELECT
    COUNT(*) AS total_listings,
    COUNT(*) FILTER (
        WHERE is_suspicious_price
    ) AS suspicious_prices,
    COUNT(*) FILTER (
        WHERE is_non_sale_listing
    ) AS non_sale_listings,
    COUNT(*) FILTER (
        WHERE is_valid_vehicle_listing
    ) AS valid_vehicle_listings
FROM used_cars.vehicles_clean;

SELECT
    id,
    price,
    manufacturer,
    model,
    seller_type,
    state,
    title
FROM used_cars.vehicles_clean
WHERE is_non_sale_listing = TRUE
ORDER BY price DESC
LIMIT 30;

SELECT
    is_suspicious_price,
    is_non_sale_listing,
    COUNT(*) AS listing_count
FROM used_cars.vehicles_clean
GROUP BY
    is_suspicious_price,
    is_non_sale_listing
ORDER BY
    is_suspicious_price DESC,
    is_non_sale_listing DESC;

SELECT
    COUNT(*) AS total_listings,
    COUNT(*) FILTER (
        WHERE is_valid_vehicle_listing
    ) AS valid_listings,
    ROUND(
        AVG(price) FILTER (
            WHERE is_valid_vehicle_listing
        ), 2
    ) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY price
        ) FILTER (
            WHERE is_valid_vehicle_listing
        )::NUMERIC, 2
    ) AS median_price
FROM used_cars.vehicles_clean;

SELECT
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY price)::NUMERIC, 2
    ) AS median_price,
    MIN(price) AS minimum_price,
    MAX(price) AS maximum_price
FROM used_cars.vehicles_clean
WHERE
    is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000;

-- Count high-price thresholds in the cleaned view.
SELECT
    COUNT(*) FILTER (WHERE price > 100000) AS over_100k,
    COUNT(*) FILTER (WHERE price > 150000) AS over_150k,
    COUNT(*) FILTER (WHERE price > 200000) AS over_200k,
    COUNT(*) FILTER (WHERE price > 250000) AS over_250k,
    COUNT(*) FILTER (WHERE price > 500000) AS over_500k,
    COUNT(*) FILTER (WHERE price > 1000000) AS over_1m
FROM used_cars.vehicles_clean;

-- Inspect records with exceptionally high prices that remain in the clean view.
SELECT
    id, price, year, manufacturer, model, condition, seller_type, state, title
FROM used_cars.vehicles_clean
WHERE price > 1000000
ORDER BY price DESC;

-- Investigate repeated extreme prices and their geographic/title distribution.
SELECT
    price,
    COUNT(*) AS listing_count,
    COUNT(DISTINCT state) AS states_represented,
    COUNT(DISTINCT title) AS unique_titles
FROM used_cars.vehicles_clean
WHERE price > 1000000
GROUP BY price
ORDER BY listing_count DESC;

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE is_valid_vehicle_listing = TRUE
    ) AS valid_listings
FROM used_cars.vehicles_clean;

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE is_valid_vehicle_listing = TRUE
    ) AS valid_flag_rows,
    COUNT(*) FILTER (
        WHERE is_valid_vehicle_listing = TRUE
          AND price BETWEEN 1 AND 100000
    ) AS valid_price_range_rows,
    COUNT(*) FILTER (
        WHERE is_suspicious_price = TRUE
    ) AS suspicious_price_rows,
    COUNT(*) FILTER (
        WHERE is_non_sale_listing = TRUE
    ) AS potential_non_sale_rows
FROM used_cars.vehicles_clean;
