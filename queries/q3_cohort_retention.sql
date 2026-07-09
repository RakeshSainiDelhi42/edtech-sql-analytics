-- Q3: Cohort retention by registration timing (all courses)
-- Cohorts: Early (>4wk before start) / Standard (0-4wk before) / Late (after start)

WITH cohorts AS (
    SELECT
        id_student,
        code_module,
        code_presentation,
        CASE
            WHEN date_registration < -28 THEN '1. Early (>4wk before)'
            WHEN date_registration < 0   THEN '2. Standard (0-4wk before)'
            ELSE                              '3. Late (after start)'
        END AS cohort
    FROM registrations
    WHERE date_registration IS NOT NULL
),
activity_months AS (
    SELECT DISTINCT
        id_student,
        code_module,
        code_presentation,
        FLOOR(activity_date / 28.0)::INT AS course_month
    FROM vle_interactions
    WHERE activity_date >= 0
)
SELECT
    c.cohort,
    COUNT(DISTINCT (c.id_student, c.code_module, c.code_presentation)) AS cohort_size,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.course_month = 0
        THEN (a.id_student, a.code_module, a.code_presentation) END)
        / COUNT(DISTINCT (c.id_student, c.code_module, c.code_presentation)), 1) AS m0_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.course_month = 1
        THEN (a.id_student, a.code_module, a.code_presentation) END)
        / COUNT(DISTINCT (c.id_student, c.code_module, c.code_presentation)), 1) AS m1_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.course_month = 3
        THEN (a.id_student, a.code_module, a.code_presentation) END)
        / COUNT(DISTINCT (c.id_student, c.code_module, c.code_presentation)), 1) AS m3_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.course_month = 6
        THEN (a.id_student, a.code_module, a.code_presentation) END)
        / COUNT(DISTINCT (c.id_student, c.code_module, c.code_presentation)), 1) AS m6_pct
FROM cohorts c
LEFT JOIN activity_months a
       ON a.id_student = c.id_student
      AND a.code_module = c.code_module
      AND a.code_presentation = c.code_presentation
GROUP BY c.cohort
ORDER BY c.cohort;