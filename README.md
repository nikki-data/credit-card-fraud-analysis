# Credit Card Fraud Analysis

## Project Overview
This project analyzes credit card transactions to identify fraud patterns and understand the factors associated with fraudulent activity.

The goal is to help a bank's fraud risk team identify suspicious transactions, reduce financial losses, and improve fraud detection strategies.

**Note:** The dataset used in this project is simulated.

## Tools & Technologies
- MySQL – Data cleaning, querying and analysis
- Microsoft Excel – Exploratory analysis and calculations
- Tableau – Data visualization and interactive dashboard
- GitHub – Project documentation and portfolio

## Project Objectives
- Identify transaction categories with higher fraud rates.
- Analyze fraud patterns by hour and weekday.
- Examine the relationship between transaction amount and fraud.
- Explore fraud patterns across age groups and states.
- Investigate transaction distance and nighttime fraud.
- Develop practical fraud alert recommendations.

## Key Findings
- Shopping Net had the highest category fraud rate at 1.76%.
- Nighttime transactions showed notable fraud patterns.
- Transactions above $500 showed elevated fraud rates.
- Weekday and state differences provided little predictive lift.
- A proposed alert rule flags approximately 1.4% of transactions while capturing 64.5% of fraud.

## Project Files
- `fraud_analysis.sql` – SQL queries used for analysis.
- `Fraud_Analysis.xlsx` – Excel analysis and supporting calculations.
- CSV files – Exported analysis results.
- [Credit Card Fraud Capstone Report](Credit_Card_Fraud_Capstone_Report1.pdf) – Final project report.

## Tableau Dashboard

[View Interactive Tableau Dashboard](https://public.tableau.com/app/profile/nikki.mishra/viz/frauddashboard_17950068488900/Dashboard1)

## Recommendations
Implement additional transaction verification, such as OTP verification or a temporary hold, for transactions of $200 or more occurring between 10 PM and 3:59 AM.

This proposed rule should be evaluated further before real-world implementation.

## Limitations
- The dataset is simulated and may not represent actual banking transactions.
- The data covers January 2019 to June 2020.
- The alert thresholds were selected after exploring the same dataset and require independent validation.

## Conclusion
This project demonstrates how SQL, Excel and Tableau can be combined to analyze financial transaction data, identify fraud patterns and communicate actionable business recommendations.
