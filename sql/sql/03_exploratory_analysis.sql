-- ============================================================
-- USED VEHICLE MARKET ANALYSIS
-- 03 - EXPLORATORY ANALYSIS
-- ============================================================
-- Purpose:
-- Answer the project's business questions using the cleaned vehicle listings.
-- Core price analysis uses valid listings priced between $1 and $100,000.
--
-- Database: data_analytics_portfolio
-- Schema:   used_cars
-- Raw table: used_cars.vehicles_raw
-- Clean view: used_cars.vehicles_clean
--
-- ============================================================

-- 3. ANALYSIS
-- ===================

-- Explore listing counts and asking-price statistics by model year.
SELECT
    year,
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY price)::NUMERIC,
        2
    ) AS median_price
FROM used_cars.vehicles_clean
WHERE
    is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND year IS NOT NULL
GROUP BY year
ORDER BY year DESC;

-- Check the posting-date range and identify unusual model years.
SELECT
    MIN(posting_date) AS earliest_posting,
    MAX(posting_date) AS latest_posting,
    COUNT(*) AS total_listings,
    COUNT(*) FILTER (
        WHERE year < 1900 OR year > 2027
    ) AS unusual_model_years
FROM used_cars.vehicles_clean
WHERE
    is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000;

SELECT
    CASE
    	WHEN year > EXTRACT(YEAR FROM posting_date::TIMESTAMPTZ)
        	THEN 'Future model year'
    	WHEN EXTRACT(YEAR FROM posting_date::TIMESTAMPTZ) - year BETWEEN 0 AND 3
       	 	THEN '0–3 years'
    	WHEN EXTRACT(YEAR FROM posting_date::TIMESTAMPTZ) - year BETWEEN 4 AND 6
        	THEN '4–6 years'
    	WHEN EXTRACT(YEAR FROM posting_date::TIMESTAMPTZ) - year BETWEEN 7 AND 10
        	THEN '7–10 years'
    	WHEN EXTRACT(YEAR FROM posting_date::TIMESTAMPTZ) - year BETWEEN 11 AND 15
        	THEN '11–15 years'
    	WHEN EXTRACT(YEAR FROM posting_date::TIMESTAMPTZ) - year BETWEEN 16 AND 20
        	THEN '16–20 years'
    	ELSE '21+ years'
		END AS vehicle_age_group,
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY price)::NUMERIC, 2
    ) AS median_price
FROM used_cars.vehicles_clean
WHERE
    is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND year IS NOT NULL
GROUP BY 1
ORDER BY MIN(EXTRACT(YEAR FROM posting_date::TIMESTAMPTZ) - year);

-- Compare asking prices across broad mileage bands, excluding odometer readings of one million or more.
SELECT
    CASE
        WHEN odometer < 25000 THEN 'Under 25k'
        WHEN odometer < 50000 THEN '25k–50k'
        WHEN odometer < 75000 THEN '50k–75k'
        WHEN odometer < 100000 THEN '75k–100k'
        WHEN odometer < 150000 THEN '100k–150k'
        WHEN odometer < 200000 THEN '150k–200k'
        ELSE '200k+'
    END AS mileage_group,
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY price)::NUMERIC, 2
    ) AS median_price
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND odometer IS NOT NULL
    AND odometer >= 0
    AND odometer < 1000000
GROUP BY 1
ORDER BY MIN(odometer);

-- Compare median asking prices by manufacturer; require at least 500 listings.
SELECT
    manufacturer,
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY price)::NUMERIC, 2
    ) AS median_price
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND NULLIF(TRIM(manufacturer), '') IS NOT NULL
GROUP BY manufacturer
HAVING COUNT(*) >= 500
ORDER BY median_price DESC;

-- Compare median asking prices by state; require at least 500 listings.
SELECT
    state,
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY price)::NUMERIC, 2
    ) AS median_price
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND NULLIF(TRIM(state), '') IS NOT NULL
GROUP BY state
HAVING COUNT(*) >= 500
ORDER BY median_price DESC;

-- Compare asking prices across reported vehicle-condition categories.
SELECT
    LOWER(TRIM(condition)) AS vehicle_condition,
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY price)::NUMERIC, 2
    ) AS median_price
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND NULLIF(TRIM(condition), '') IS NOT NULL
GROUP BY 1
ORDER BY median_price DESC;

-- Inspect high-priced examples labeled salvage.
SELECT
    year,
    manufacturer,
    model,
    price,
    odometer,
    seller_type,
    state,
    title
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND LOWER(TRIM(condition)) = 'salvage'
ORDER BY price DESC
LIMIT 20;

-- Identify repeated salvage title/price combinations across listings and states.
SELECT
    title,
    price,
    COUNT(*) AS listing_count,
    COUNT(DISTINCT state) AS states_listed
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND LOWER(TRIM(condition)) = 'salvage'
GROUP BY title, price
HAVING COUNT(*) > 1
ORDER BY listing_count DESC
LIMIT 20;

-- Quantify repeated title/price combinations among salvage listings.
SELECT
    COUNT(*) AS total_salvage_listings,
    COUNT(DISTINCT title) AS unique_titles,
    COUNT(DISTINCT (title, price)) AS unique_title_price_pairs,
    COUNT(*) - COUNT(DISTINCT (title, price)) AS repeated_listings
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND LOWER(TRIM(condition)) = 'salvage';

-- Compare dealer and owner listing counts and asking-price statistics.
SELECT
    seller_type,
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY price)::NUMERIC, 2
    ) AS median_price
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND seller_type IS NOT NULL
GROUP BY seller_type
ORDER BY median_price DESC;

-- Identify the 15 most frequently listed manufacturers and their share of listings.
SELECT
    manufacturer,
    COUNT(*) AS listing_count,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (), 2
    ) AS percentage_of_listings
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND NULLIF(TRIM(manufacturer), '') IS NOT NULL
GROUP BY manufacturer
ORDER BY listing_count DESC
LIMIT 15;

-- Profile mileage percentiles and range before the 1,000,000-mile exclusion.
-- This diagnostic retains extreme values so the maximum can be inspected;
-- downstream mileage price comparisons apply the < 1,000,000-mile cutoff.
SELECT
    COUNT(*) AS listing_count,
    MIN(odometer) AS minimum_mileage,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY odometer) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY odometer) AS median_mileage,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY odometer) AS p75,
    MAX(odometer) AS maximum_mileage
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
  AND price BETWEEN 1 AND 100000
  AND odometer IS NOT NULL
  AND odometer >= 0;

-- Inspect the highest odometer values below the one-million-mile cutoff.
SELECT
    odometer,
    COUNT(*) AS listing_count
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
  AND price BETWEEN 1 AND 100000
  AND odometer >= 300000
GROUP BY odometer
ORDER BY odometer DESC
LIMIT 20;

-- Inspect examples with odometer readings of one million miles or more.
SELECT
    year,
    manufacturer,
    model,
    odometer,
    price,
    state
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
  AND price BETWEEN 1 AND 100000
  AND odometer >= 1000000
ORDER BY odometer DESC
LIMIT 30;

-- Measure the number and percentage of extreme odometer values among valid listings.
SELECT
    COUNT(*) AS total_listings,
    COUNT(*) FILTER (WHERE odometer >= 1000000) AS excluded_listings,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE odometer >= 1000000)
        / COUNT(*), 2
    ) AS excluded_percentage
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
  AND price BETWEEN 1 AND 100000
  AND odometer IS NOT NULL;

SELECT
    CASE
        WHEN odometer < 25000 THEN 'Under 25K'
        WHEN odometer < 50000 THEN '25K–49,999'
        WHEN odometer < 75000 THEN '50K–74,999'
        WHEN odometer < 100000 THEN '75K–99,999'
        WHEN odometer < 125000 THEN '100K–124,999'
        WHEN odometer < 150000 THEN '125K–149,999'
        WHEN odometer < 200000 THEN '150K–199,999'
        WHEN odometer < 300000 THEN '200K–299,999'
        ELSE '300K–999,999'
    END AS mileage_group,
    COUNT(*) AS listing_count
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
  AND price BETWEEN 1 AND 100000
  AND odometer IS NOT NULL
  AND odometer >= 0
  AND odometer < 1000000
GROUP BY 1
ORDER BY MIN(odometer);

-- =========================================================
-- 4. MANUFACTURER ANALYSIS
-- Purpose: Compare listing volume and median asking prices
-- across vehicle manufacturers.
-- =========================================================

SELECT
    manufacturer,
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY price) AS median_price
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND manufacturer IS NOT NULL
GROUP BY manufacturer
HAVING COUNT(*) >= 500
ORDER BY median_price DESC;


-- =========================================================
-- 5. SELLER TYPE ANALYSIS
-- Purpose: Compare listing volume and asking prices
-- between dealer and owner listings.
-- =========================================================

SELECT
    seller_type,
    COUNT(*) AS listing_count,
    ROUND(AVG(price), 2) AS average_price,
    PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY price) AS median_price
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
    AND price BETWEEN 1 AND 100000
    AND seller_type IS NOT NULL
GROUP BY seller_type
ORDER BY median_price DESC;
