-- =====================================================================
-- CREDIT CARD FRAUD ANALYSIS: FULL SQL SCRIPT (MySQL 8)
-- Data: fraudTrain.csv (simulated transactions, Jan 2019 - Jun 2020)
--
-- HOW TO USE
--   1. Run ONE block at a time: highlight the block, click the lightning bolt.
--   2. Read the comment above each block BEFORE you run it.
--   3. If a block fails, copy the exact error message and send it to Claude.
--   4. Run the parts in order: PART 1 -> PART 2 -> PART 3 -> PART 4.
-- =====================================================================

USE fraud_project;


-- =====================================================================
-- PART 1: DATA CHECKS (Prepare + Process phases)
-- Goal: confirm the data is trustworthy before analysing it.
-- =====================================================================

-- 1.1 Duplicate check
-- trans_num is the transaction ID. If both numbers match, there are no duplicates.
SELECT COUNT(*)                   AS total_rows,
       COUNT(DISTINCT trans_num)  AS unique_transactions
FROM fraud;

-- 1.2 Do the amounts make sense?
-- Look for zero or negative amounts, and an unusually huge maximum.
SELECT MIN(amt)            AS smallest_amount,
       MAX(amt)            AS largest_amount,
       ROUND(AVG(amt), 2)  AS average_amount,
       SUM(amt <= 0)       AS zero_or_negative_rows
FROM fraud;

-- 1.3 Categories and their sizes
-- Look for duplicated or misspelled category names.
SELECT category, COUNT(*) AS transactions
FROM fraud
GROUP BY category
ORDER BY transactions DESC;

-- 1.4 Merchant prefix check
-- Merchant names start with "fraud_" (e.g. fraud_Kirlin and Sons).
-- This is just part of the simulator's naming, NOT a fraud flag.
-- We expect 0 rows WITHOUT the prefix. We will remove it in Part 2.
SELECT COUNT(*) AS rows_without_prefix
FROM fraud
WHERE LEFT(merchant, 6) <> 'fraud_';

-- 1.5 How many different cards, merchants, states, categories?
SELECT COUNT(DISTINCT cc_num)    AS cards,
       COUNT(DISTINCT merchant)  AS merchants,
       COUNT(DISTINCT state)     AS states,
       COUNT(DISTINCT category)  AS categories
FROM fraud;

-- 1.6 Customer birth date range (sanity check before calculating age)
SELECT MIN(dob) AS oldest_birth_date,
       MAX(dob) AS youngest_birth_date
FROM fraud;


-- =====================================================================
-- PART 2: CREATE THE CLEAN TABLE (Process phase)
-- Goal: build a new table "fraud_clean" with useful new columns.
-- The original "fraud" table stays untouched, so you can always go back.
--
-- New columns created:
--   trans_hour, dow_name, trans_month  -> from the date/time
--   merchant (cleaned)                 -> "fraud_" prefix removed
--   age                                -> age at the time of the transaction
--   distance_km                        -> customer home to merchant, in km
--   amount_band, age_group             -> buckets so we can compare groups
--
-- PRIVACY NOTE: we deliberately leave out first_name, last_name, street
-- and cc_num. The analysis does not need them, and good analysts do not
-- carry personal data forward unnecessarily. (Good interview point!)
--
-- This block may take 1-3 minutes on 1.3 million rows. Wait for it.
-- =====================================================================

DROP TABLE IF EXISTS fraud_clean;

CREATE TABLE fraud_clean AS
SELECT
    b.row_id,
    b.trans_num,
    b.trans_date_time,
    b.trans_date,
    b.trans_month,
    b.trans_hour,
    b.dow_num,
    b.dow_name,
    b.merchant,
    b.category,
    b.amt,
    CASE
        WHEN b.amt <   10 THEN '1) Under $10'
        WHEN b.amt <   50 THEN '2) $10-49'
        WHEN b.amt <  100 THEN '3) $50-99'
        WHEN b.amt <  200 THEN '4) $100-199'
        WHEN b.amt <  500 THEN '5) $200-499'
        WHEN b.amt < 1000 THEN '6) $500-999'
        ELSE                   '7) $1000+'
    END AS amount_band,
    b.gender,
    b.city,
    b.state,
    b.city_pop,
    b.job,
    b.age,
    CASE
        WHEN b.age < 25 THEN '1) Under 25'
        WHEN b.age < 35 THEN '2) 25-34'
        WHEN b.age < 45 THEN '3) 35-44'
        WHEN b.age < 55 THEN '4) 45-54'
        WHEN b.age < 65 THEN '5) 55-64'
        ELSE                 '6) 65+'
    END AS age_group,
    b.distance_km,
    b.is_fraud
FROM (
    SELECT
        row_id,
        trans_num,
        trans_date_time,
        DATE(trans_date_time)                    AS trans_date,
        DATE_FORMAT(trans_date_time, '%Y-%m')    AS trans_month,
        HOUR(trans_date_time)                    AS trans_hour,
        DAYOFWEEK(trans_date_time)               AS dow_num,   -- 1 = Sunday ... 7 = Saturday
        DAYNAME(trans_date_time)                 AS dow_name,
        SUBSTRING(merchant, 7)                   AS merchant,  -- drops the first 6 characters "fraud_"
        category,
        amt,
        gender,
        city,
        state,
        city_pop,
        job,
        TIMESTAMPDIFF(YEAR, dob, trans_date_time) AS age,
        -- Straight-line distance in km. POINT takes (longitude, latitude), in that order.
        ROUND(ST_Distance_Sphere(POINT(longitude, lat),
                                 POINT(merch_long, merch_lat)) / 1000, 1) AS distance_km,
        is_fraud
    FROM fraud
) b;

-- 2.1 Verify: row count should be 1296675, same as the original table
SELECT COUNT(*) AS clean_rows FROM fraud_clean;

-- 2.2 Verify: look at 5 rows
SELECT * FROM fraud_clean LIMIT 5;

-- 2.3 Verify: do the new columns look sensible?
SELECT MIN(age)          AS youngest,
       MAX(age)          AS oldest,
       MIN(distance_km)  AS min_distance_km,
       MAX(distance_km)  AS max_distance_km,
       ROUND(AVG(distance_km), 1) AS avg_distance_km
FROM fraud_clean;

-- 2.4 Verify: merchant names no longer start with "fraud_"
SELECT merchant FROM fraud_clean LIMIT 5;


-- =====================================================================
-- PART 3: ANALYSIS (Analyze phase)
-- Each query answers one of your guiding questions.
-- KEY IDEA: always compare fraud RATE, not just fraud counts.
--   fraud_rate_pct = fraud transactions / total transactions * 100
-- Overall fraud rate is about 0.58%, so anything clearly above that is
-- "higher risk" and anything clearly below is "lower risk".
-- =====================================================================

-- 3.1 Which merchant categories have the highest fraud rate?   (Guiding Q1)
SELECT category,
       COUNT(*)                                        AS total_txns,
       SUM(is_fraud)                                   AS fraud_txns,
       ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)      AS fraud_rate_pct,
       ROUND(SUM(amt * is_fraud), 2)                   AS fraud_amount
FROM fraud_clean
GROUP BY category
ORDER BY fraud_rate_pct DESC;

-- 3.2 Which hours of the day have the highest fraud rate?      (Guiding Q2)
SELECT trans_hour,
       COUNT(*)                                        AS total_txns,
       SUM(is_fraud)                                   AS fraud_txns,
       ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)      AS fraud_rate_pct
FROM fraud_clean
GROUP BY trans_hour
ORDER BY trans_hour;

-- 3.3 Which days of the week?                                  (Guiding Q2)
SELECT dow_name,
       COUNT(*)                                        AS total_txns,
       SUM(is_fraud)                                   AS fraud_txns,
       ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)      AS fraud_rate_pct
FROM fraud_clean
GROUP BY dow_num, dow_name
ORDER BY dow_num;

-- 3.4 Which transaction amounts are linked to fraud?           (Guiding Q3)
SELECT amount_band,
       COUNT(*)                                        AS total_txns,
       SUM(is_fraud)                                   AS fraud_txns,
       ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)      AS fraud_rate_pct
FROM fraud_clean
GROUP BY amount_band
ORDER BY amount_band;

-- 3.5 Does fraud differ by customer age group?                 (Guiding Q4)
SELECT age_group,
       COUNT(*)                                        AS total_txns,
       SUM(is_fraud)                                   AS fraud_txns,
       ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)      AS fraud_rate_pct
FROM fraud_clean
GROUP BY age_group
ORDER BY age_group;

-- 3.6 Does fraud differ by state?                              (Guiding Q4)
-- HAVING keeps only states with at least 5,000 transactions, so tiny
-- groups do not give misleading rates.
SELECT state,
       COUNT(*)                                        AS total_txns,
       SUM(is_fraud)                                   AS fraud_txns,
       ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)      AS fraud_rate_pct
FROM fraud_clean
GROUP BY state
HAVING COUNT(*) >= 5000
ORDER BY fraud_rate_pct DESC;

-- 3.7 Is fraud made farther from the customer's home?          (Guiding Q5)
SELECT is_fraud,
       COUNT(*)                     AS txns,
       ROUND(AVG(distance_km), 1)   AS avg_distance_km,
       MIN(distance_km)             AS min_distance_km,
       MAX(distance_km)             AS max_distance_km
FROM fraud_clean
GROUP BY is_fraud;

-- 3.8 Fraud over time (monthly trend)
-- NOTE: June 2020 is a PARTIAL month (data ends 21 June). Mention this in
-- your report rather than hiding it.
SELECT trans_month,
       COUNT(*)                                        AS total_txns,
       SUM(is_fraud)                                   AS fraud_txns,
       ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)      AS fraud_rate_pct
FROM fraud_clean
GROUP BY trans_month
ORDER BY trans_month;

-- 3.9 Money impact: how big are fraud transactions vs normal ones?
SELECT is_fraud,
       COUNT(*)              AS txns,
       ROUND(AVG(amt), 2)    AS avg_amount,
       ROUND(MAX(amt), 2)    AS max_amount,
       ROUND(SUM(amt), 2)    AS total_amount
FROM fraud_clean
GROUP BY is_fraud;

-- 3.10 Risky combinations: category + night vs daytime
-- Night = 10pm to 3:59am. This is where "alert rules" for the bank come from.
SELECT category,
       CASE WHEN trans_hour >= 22 OR trans_hour <= 3
            THEN 'Night (10pm-3:59am)'
            ELSE 'Daytime' END                         AS time_of_day,
       COUNT(*)                                        AS total_txns,
       SUM(is_fraud)                                   AS fraud_txns,
       ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2)      AS fraud_rate_pct
FROM fraud_clean
GROUP BY category, time_of_day
HAVING COUNT(*) >= 1000
ORDER BY fraud_rate_pct DESC
LIMIT 15;


-- =====================================================================
-- PART 4: EXPORT RESULTS FOR EXCEL AND TABLEAU (Share phase)
-- After running each query in Part 3:
--   1. In the Result Grid, click the "Export" icon (above the results).
--   2. Choose CSV, and save in your project folder (C:\capstone project).
--   3. Use these file names so you stay organised:
--        3.1 -> 01_fraud_by_category.csv
--        3.2 -> 02_fraud_by_hour.csv
--        3.3 -> 03_fraud_by_weekday.csv
--        3.4 -> 04_fraud_by_amount_band.csv
--        3.5 -> 05_fraud_by_age_group.csv
--        3.6 -> 06_fraud_by_state.csv
--        3.7 -> 07_distance_fraud_vs_legit.csv
--        3.8 -> 08_fraud_by_month.csv
--        3.9 -> 09_amount_fraud_vs_legit.csv
--        3.10 -> 10_category_night_combo.csv
--   4. Open them in Excel for pivot tables/charts, and connect Tableau
--      to the same CSV files for the dashboard.
-- =====================================================================
