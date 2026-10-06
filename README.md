![E-commerce Analysis with SQL](readme-banner.png)

# E-commerce Analysis with SQL

**Google BigQuery · Google Analytics Sample · 10 analytical questions**

![SQL: GoogleSQL](https://img.shields.io/badge/SQL-GoogleSQL-7C3AED?style=for-the-badge&labelColor=312E81)
![Google BigQuery](https://img.shields.io/badge/Google-BigQuery-2563EB?style=for-the-badge&labelColor=1E3A8A)
![Dataset: Google Analytics Sample](https://img.shields.io/badge/Dataset-Google%20Analytics%20Sample-0891B2?style=for-the-badge&labelColor=164E63)
![Queries: 10](https://img.shields.io/badge/Queries-10-F97316?style=for-the-badge&labelColor=9A3412)

# E-commerce Analysis with SQL

**Google BigQuery · Google Analytics Sample · 10 analytical questions**

> SQL analysis of website traffic, purchasing behavior, and product revenue for an e-commerce store. The project uses Google Merchandise Store data to examine traffic sources, purchasing customer groups, and device contributions to business activity.

**[View all SQL queries](ecommerce_analysis.sql)**

### 🎯Analysis objectives

- **Website performance:** track visits, pageviews, transactions, and revenue over time.
- **Traffic sources:** examine traffic volume, bounce rate, and the share of sessions with a purchase.
- **Customer behavior:** compare pageviews across customer groups and transactions per purchaser.
- **Products and devices:** analyze revenue contributions and other products purchased by the same customer group.

### Dataset

### Dataset

### 🗂️Dataset

| | |
|---|---|
| **Source:** | [Google Analytics Sample from the Google Merchandise Store](https://blog.google/products/marketingplatform/analytics/introducing-google-analytics-sample/). |
| **Dataset:** | `bigquery-public-data.google_analytics_sample`. |
| **Tables:** | `ga_sessions_2017*`, with a specific date filter in each query. |
| **Tool:** | SQL in Google BigQuery, using the GoogleSQL dialect. |
| **Scope:** | selected periods in 2017. Q04 and Q07 use the available 2017 dates in the dataset; their results represent the observed dates rather than an assumed full 12 months.

### 🔎Accessing the dataset

<details>
<summary><strong>View dataset access instructions</strong></summary>

The dataset is publicly available in BigQuery and can be queried directly without downloading the source data.

**[Open Google Analytics Sample in BigQuery](https://console.cloud.google.com/bigquery?p=bigquery-public-data&d=google_analytics_sample&page=dataset)**

The execution environment requires a Google account and a Google Cloud project with permission to run BigQuery queries. Query jobs run in the executing account's project; `bigquery-public-data` hosts the source data.

In **BigQuery Studio → Explorer**, the source is organized as follows:

```text
bigquery-public-data
└── google_analytics_sample
    └── ga_sessions_YYYYMMDD
```

If the public project is not visible in Explorer, it can be found through resource search. In interfaces that include **Add / Add data → Star a project by name**, the project can be added using `bigquery-public-data`, followed by opening the `google_analytics_sample` dataset.

Daily tables follow the `ga_sessions_YYYYMMDD` naming convention, for example `ga_sessions_20170701`. The **Schema** and **Preview** tabs show the field structure and sample rows. The `ga_sessions_2017*` wildcard combines tables with the 2017 prefix; `_TABLE_SUFFIX` limits the dates included in each analysis.

Interface documentation: [BigQuery Studio](https://docs.cloud.google.com/bigquery/docs/bigquery-web-ui) and [Google Cloud: accessing Google Analytics Sample](https://www.cloudskillsboost.google/course_templates/624/labs/548383).

</details>

### 💡Analysis questions

<details open>
<summary><strong>1. Website performance</strong></summary>

- [Q01](ecommerce_analysis.sql#L13) — Monthly visits, pageviews, and transactions from January to March 2017.
- [Q10](ecommerce_analysis.sql#L257) — Weekly and cumulative product revenue from May to July 2017.

</details>

<details>
<summary><strong>2. Traffic source performance</strong></summary>

- [Q02](ecommerce_analysis.sql#L27) — Bounce rate and traffic volume by source in July 2017.
- [Q03](ecommerce_analysis.sql#L44) — Product revenue by traffic source, aggregated by week and month in June 2017.
- [Q04](ecommerce_analysis.sql#L82) — Purchase-session rate by source across the available 2017 dates.

</details>

<details>
<summary><strong>3. Purchasing behavior and devices</strong></summary>

- [Q05](ecommerce_analysis.sql#L109) — Average pageviews for purchasers and non-purchasers, classified separately for June and July 2017.
- [Q06](ecommerce_analysis.sql#L136) — Average transactions per purchasing visitor ID in July 2017.
- [Q07](ecommerce_analysis.sql#L161) — Product revenue and revenue share by device category across the available 2017 dates.

</details>

<details>
<summary><strong>4. Product analysis</strong></summary>

- [Q08](ecommerce_analysis.sql#L187) — Other products purchased in July 2017 by visitor IDs that purchased “YouTube Men's Vintage Henley”.
- [Q09](ecommerce_analysis.sql#L218) — Ratios of add-to-cart and purchase records to product detail view records, by product name, from January to March 2017.

</details>

### 🧩Analytical approach

1. **Observation window and unit of analysis:** each question specifies its date range and aggregation level, such as session, visitor ID, traffic source, device, or product.
2. **Aggregation at the appropriate level:** visits, pageviews, and transactions are calculated from session data; product revenue and product actions are calculated from product rows after `UNNEST`. This structure avoids multiplying session metrics when nested data is expanded.
3. **Consistent metric definitions:** rates use explicit denominators, revenue is converted to the dataset's currency units, and weeks follow a Monday-start convention.
4. **Comparable analytical outputs:** queries produce grouped metrics, source or product rankings, revenue shares, and cumulative revenue. Each output is interpreted within its own observation window and metric definition.

### 🛠️SQL techniques applied

- **Aggregation and grouping:** `SUM`, `COUNT`, `COUNTIF`, and `GROUP BY` calculate metrics by month, source, customer group, and product.
- **Query organization:** CTEs, `JOIN`, and `UNION ALL` separate analytical steps and combine the required datasets.
- **Nested data:** `UNNEST` accesses hits and products, while session metrics are aggregated at the session level to avoid double counting.
- **Ratios and missing values:** `SAFE_DIVIDE`, `COALESCE`, and `ROUND` handle calculations while keeping outputs numeric for sorting and reconciliation.
- **Time-based analysis:** `PARSE_DATE`, `DATE_TRUNC`, and window functions calculate weekly revenue, revenue shares, and cumulative totals.

<details>
<summary><strong>Metric definitions and interpretation limits</strong></summary>

- **Visits:** Q01 and Q02 use the sum of `totals.visits`; the number of exported rows may differ from the number of counted visits.
- **Bounce rate:** bounces / visits × 100, within the same observation window.
- **Purchase-session rate:** Q04 considers sessions with `totals.visits = 1`; the rate is sessions with at least one transaction / included sessions × 100. Only sources with at least 50 transactions are shown. Transactions per 100 sessions is reported separately.
- **Purchaser groups:** Q05 aggregates each visitor ID within a month. An ID with at least one transaction is classified as a purchaser; average pageviews include all of that ID's session pageviews in the month.
- **Product revenue:** the sum of `productRevenue`, converted to the dataset's currency units. This metric does not represent profit or the incremental effect of advertising.
- **Products purchased by the same customer group:** Q08 identifies products bought by the same visitor IDs within the month; it does not establish that the products were purchased in the same order.
- **Product-action ratios:** Q09 counts action records by product name rather than tracking a sequential funnel for the same customers. A zero denominator returns NULL, and ratios may exceed 100%.
- **Observation windows:** queries cover different periods. Q01 returns months as `YYYYMM`. Q03 uses `time_type` to distinguish `Month` and `Week`, with a `period` value formatted as `YYYYMM` or `YYYYWW`. Weeks start on Monday, and boundary weeks contain only the dates within the selected window.

</details>

### 🔁Reproducibility

All SQL is contained in [ecommerce_analysis.sql](ecommerce_analysis.sql), with 10 independent query blocks labeled **Q01** through **Q10**. Each block is executed separately in BigQuery's **GoogleSQL** editor through **SQL query → Run**; outputs appear in the **Results** tab.

The queries read public tables directly, create no tables, and do not depend on each other's results. Date filters, grouping logic, and metric formulas are specified in each SQL block. The execution location must match the source dataset's location, as described in the [BigQuery query documentation](https://docs.cloud.google.com/bigquery/docs/running-queries).

📁Project files

| File | Description |
|---|---|
| **[README.md](README.md):** | business context, data source, dataset access, analytical questions, and methodology. |
| **[ecommerce_analysis.sql](ecommerce_analysis.sql):** | 10 SQL queries addressing the analytical questions. |

**Version status:** all 10 queries have passed a local syntax check. This version does not include execution results validated in BigQuery.

### 📚References

- [Universal Analytics — BigQuery Export schema](https://support.google.com/analytics/answer/3437719?hl=en).
- [BigQuery — Arrays and UNNEST](https://docs.cloud.google.com/bigquery/docs/arrays).

- [Universal Analytics — BigQuery Export schema](https://support.google.com/analytics/answer/3437719?hl=en).
- [BigQuery — Arrays and UNNEST](https://docs.cloud.google.com/bigquery/docs/arrays).
