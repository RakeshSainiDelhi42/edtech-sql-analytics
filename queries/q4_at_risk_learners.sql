-- Q4: At-risk learner identification (DDD 2013J, as of day 150)
-- Signals: Recency + Frequency-vs-baseline + Performance -> risk score

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
        COALESCE(r.days_inactive, 999)      AS days_inactive,
        COALESCE(f.active_days_last_28, 0)  AS active_days_last_28,
        COALESCE(f.baseline_days_per_28, 0) AS baseline_days_per_28,
        p.avg_score,
        -- Recency component (0-3)
        CASE WHEN COALESCE(r.days_inactive, 999) >= 21 THEN 3
             WHEN r.days_inactive >= 14 THEN 2
             WHEN r.days_inactive >= 7  THEN 1
             ELSE 0 END
        -- Frequency component (0-3)
      + CASE WHEN COALESCE(f.active_days_last_28, 0) = 0 THEN 3
             WHEN f.active_days_last_28 < f.baseline_days_per_28 * 0.5 THEN 2
             WHEN f.active_days_last_28 < f.baseline_days_per_28 THEN 1
             ELSE 0 END
        -- Performance component (0-3)
      + CASE WHEN p.avg_score IS NULL THEN 2
             WHEN p.avg_score < 40 THEN 3
             WHEN p.avg_score < 55 THEN 1
             ELSE 0 END                     AS risk_score
    FROM active_learners a
    LEFT JOIN recency     r ON r.id_student = a.id_student
    LEFT JOIN frequency   f ON f.id_student = a.id_student
    LEFT JOIN performance p ON p.id_student = a.id_student
)
SELECT
    id_student,
    days_inactive,
    active_days_last_28,
    baseline_days_per_28,
    avg_score,
    risk_score,
    CASE WHEN risk_score >= 7 THEN 'CRITICAL - contact this week'
         WHEN risk_score >= 5 THEN 'HIGH - add to nudge campaign'
         WHEN risk_score >= 3 THEN 'WATCH'
         ELSE 'HEALTHY' END AS risk_band
FROM scored
ORDER BY risk_score DESC, days_inactive DESC
LIMIT 25;