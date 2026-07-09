-- Q1: Which courses have the highest early engagement (first 28 days)?

WITH first_month AS (
    SELECT
        code_module,
        code_presentation,
        id_student,
        SUM(sum_click)                AS clicks_first_28d,
        COUNT(DISTINCT activity_date) AS active_days_first_28d
    FROM vle_interactions
    WHERE activity_date BETWEEN 0 AND 27
    GROUP BY code_module, code_presentation, id_student
),
registered AS (
    SELECT code_module, code_presentation, COUNT(*) AS registered_learners
    FROM registrations
    GROUP BY code_module, code_presentation
)
SELECT
    r.code_module,
    r.code_presentation,
    r.registered_learners,
    COUNT(f.id_student) AS engaged_learners,
    ROUND(100.0 * COUNT(f.id_student) / r.registered_learners, 1) AS pct_engaged,
    ROUND(AVG(f.clicks_first_28d), 1)      AS avg_clicks_per_engaged,
    ROUND(AVG(f.active_days_first_28d), 1) AS avg_active_days
FROM registered r
LEFT JOIN first_month f
       ON f.code_module = r.code_module
      AND f.code_presentation = r.code_presentation
GROUP BY r.code_module, r.code_presentation, r.registered_learners
ORDER BY pct_engaged DESC;