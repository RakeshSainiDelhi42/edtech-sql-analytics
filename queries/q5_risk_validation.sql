-- Q5: Validation - do risk bands (scored at day 150) predict final outcomes?

WITH active_learners AS (
    SELECT id_student
    FROM registrations
    WHERE code_module = 'DDD' AND code_presentation = '2013J'
      AND (date_unregistration IS NULL OR date_unregistration > 150)
),
recency AS (
    SELECT id_student,
           150 - MAX(activity_date) AS days_inactive
    FROM vle_interactions
    WHERE code_module = 'DDD' AND code_presentation = '2013J'
      AND activity_date <= 150
    GROUP BY id_student
),
frequency AS (
    SELECT id_student,
           COUNT(DISTINCT activity_date) FILTER (WHERE activity_date > 122)
               AS active_days_last_28,
           ROUND(COUNT(DISTINCT activity_date) / (150 / 28.0), 1)
               AS baseline_days_per_28
    FROM vle_interactions
    WHERE code_module = 'DDD' AND code_presentation = '2013J'
      AND activity_date BETWEEN 0 AND 150
    GROUP BY id_student
),
performance AS (
    SELECT sa.id_student,
           ROUND(AVG(sa.score), 1) AS avg_score
    FROM student_assessments sa
    JOIN assessments a ON a.id_assessment = sa.id_assessment
    WHERE a.code_module = 'DDD' AND a.code_presentation = '2013J'
      AND sa.date_submitted <= 150
    GROUP BY sa.id_student
),
scored AS (
    SELECT
        a.id_student,
        CASE WHEN COALESCE(r.days_inactive, 999) >= 21 THEN 3
             WHEN r.days_inactive >= 14 THEN 2
             WHEN r.days_inactive >= 7  THEN 1
             ELSE 0 END
      + CASE WHEN COALESCE(f.active_days_last_28, 0) = 0 THEN 3
             WHEN f.active_days_last_28 < f.baseline_days_per_28 * 0.5 THEN 2
             WHEN f.active_days_last_28 < f.baseline_days_per_28 THEN 1
             ELSE 0 END
      + CASE WHEN p.avg_score IS NULL THEN 2
             WHEN p.avg_score < 40 THEN 3
             WHEN p.avg_score < 55 THEN 1
             ELSE 0 END AS risk_score
    FROM active_learners a
    LEFT JOIN recency     r ON r.id_student = a.id_student
    LEFT JOIN frequency   f ON f.id_student = a.id_student
    LEFT JOIN performance p ON p.id_student = a.id_student
)
SELECT
    CASE WHEN s.risk_score >= 7 THEN '1. CRITICAL (7-9)'
         WHEN s.risk_score >= 5 THEN '2. HIGH (5-6)'
         WHEN s.risk_score >= 3 THEN '3. WATCH (3-4)'
         ELSE                        '4. HEALTHY (0-2)' END AS risk_band,
    COUNT(*) AS learners,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.final_result IN ('Withdrawn','Fail'))
        / COUNT(*), 1) AS pct_bad_outcome,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.final_result = 'Withdrawn')
        / COUNT(*), 1) AS pct_withdrawn,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.final_result IN ('Pass','Distinction'))
        / COUNT(*), 1) AS pct_passed
FROM scored s
JOIN registrations r
  ON r.id_student = s.id_student
 AND r.code_module = 'DDD' AND r.code_presentation = '2013J'
GROUP BY 1
ORDER BY 1;