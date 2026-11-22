-- 1900-01-01 covers the placeholder date used for unknown values
WITH days AS (
    {{ dbt_utils.date_spine(datepart="day", start_date="cast('1900-01-01' as date)", end_date="cast('2031-01-01' as date)") }}
)
SELECT
    CAST(date_format(days.date_day, 'yyyyMMdd') AS INT)   AS date_key
  , CAST(days.date_day AS DATE)                           AS date
  , year(days.date_day)                                   AS year
  , quarter(days.date_day)                                AS quarter
  , month(days.date_day)                                  AS month
  , date_format(days.date_day, 'MMMM')                    AS month_name
  , date_format(days.date_day, 'EEEE')                    AS day_name
FROM
    days