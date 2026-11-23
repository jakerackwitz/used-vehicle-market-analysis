-- ============================================================
-- USED VEHICLE MARKET ANALYSIS
-- 04 - TABLEAU DATA EXPORT
-- ============================================================
-- Purpose:
-- Select the curated fields used in the Tableau Public dashboard.
--
-- This query returns valid vehicle listings within the primary
-- asking-price range. Export the result set from DBeaver as CSV
-- for use as the Tableau data source.
--
-- Database: data_analytics_portfolio
-- Schema:   used_cars
-- Source:   used_cars.vehicles_clean
-- ============================================================

SELECT
    id,
    price,
    year,
    manufacturer,
    model,
    condition,
    cylinders,
    fuel,
    odometer,
    transmission,
    drive,
    type,
    paint_color,
    state,
    lat,
    long,
    seller_type,
    posting_date
FROM used_cars.vehicles_clean
WHERE is_valid_vehicle_listing = TRUE
  AND price BETWEEN 1 AND 100000;
