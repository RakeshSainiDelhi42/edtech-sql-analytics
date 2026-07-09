-- Q2: Where do learners drop off? (course DDD, presentation 2013J)
-- Funnel: Registered → Engaged → First assessment → Midpoint → Completed

WITH registered AS (
    SELECT id_student
    FROM registrations
    WHERE code_module = 'DDD' AND code_presentation = '2013J'
),
engaged AS (
    SELECT DISTINCT id_student
    FROM vle_interactions
    WHERE code_module = 'DDD' AND code_presentation = '2013J'
      AND id_student IN (SELECT id_student FROM registered)
),
first_assessment AS (
    SELECT DISTINCT sa.id_student
    FROM student_assessments sa
    JOIN assessments a ON a.id_assessment = sa.id_assessment
    WHERE a.code_module = 'DDD' AND a.code_presentation = '2013J'
      AND a.date_due = (
          SELECT MIN(date_due) FROM assessments
          WHERE code_module = 'DDD' AND code_presentation = '2013J'
            AND assessment_type <> 'Exam'
      )
),
midpoint AS (
    SELECT DISTINCT v.id_student
    FROM vle_interactions v
    JOIN courses c ON c.code_module = v.code_module
                  AND c.code_presentation = v.code_presentation
    WHERE v.code_module = 'DDD' AND v.code_presentation = '2013J'
      AND v.activity_date >= c.length_days / 2
),
completed AS (
    SELECT id_student
    FROM registrations
    WHERE code_module = 'DDD' AND code_presentation = '2013J'
      AND final_result IN ('Pass', 'Distinction')
),
funnel AS (
    SELECT 1 AS stage_order, 'Registered' AS stage,               COUNT(*) AS learners FROM registered
    UNION ALL
    SELECT 2, 'Engaged (clicked at least once)',                  COUNT(*) FROM engaged
    UNION ALL
    SELECT 3, 'Submitted first assessment',                       COUNT(*) FROM first_assessment
    UNION ALL
    SELECT 4, 'Active past midpoint',                             COUNT(*) FROM midpoint
    UNION ALL
    SELECT 5, 'Completed (Pass/Distinction)',                     COUNT(*) FROM completed
)
SELECT
    stage,
    learners,
    ROUND(100.0 * learners / FIRST_VALUE(learners) OVER (ORDER BY stage_order), 1)
        AS pct_of_registered,
    ROUND(100.0 * (learners - LAG(learners) OVER (ORDER BY stage_order))
        / NULLIF(LAG(learners) OVER (ORDER BY stage_order), 0), 1)
        AS drop_from_prev_pct
FROM funnel
ORDER BY stage_order;