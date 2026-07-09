-- =========================================================
-- Re-runnable loader: clears tables, then loads fresh
-- =========================================================

-- Clear courses and everything that depends on it
TRUNCATE courses, students CASCADE;

-- ---- courses: clean file, direct load ----
\copy courses FROM 'data/courses.csv' CSV HEADER

-- ---- assessments: has '?' for missing values, so stage it ----
DROP TABLE IF EXISTS stg_assessments;
CREATE TABLE stg_assessments (
    code_module        TEXT,
    code_presentation  TEXT,
    id_assessment      TEXT,
    assessment_type    TEXT,
    date_due           TEXT,
    weight             TEXT
);

\copy stg_assessments FROM 'data/assessments.csv' CSV HEADER

INSERT INTO assessments (id_assessment, code_module, code_presentation,
                         assessment_type, date_due, weight)
SELECT id_assessment::INT,
       code_module,
       code_presentation,
       assessment_type,
       NULLIF(date_due, '?')::INT,
       NULLIF(weight,  '?')::NUMERIC
FROM stg_assessments;

DROP TABLE stg_assessments;

-- ---- students: studentInfo.csv has one row per student PER COURSE ----
-- We keep demographics only, deduplicated to one row per student.
DROP TABLE IF EXISTS stg_student_info;
CREATE TABLE stg_student_info (
    code_module          TEXT,
    code_presentation    TEXT,
    id_student           TEXT,
    gender               TEXT,
    region               TEXT,
    highest_education    TEXT,
    imd_band             TEXT,
    age_band             TEXT,
    num_of_prev_attempts TEXT,
    studied_credits      TEXT,
    disability           TEXT,
    final_result         TEXT
);

\copy stg_student_info FROM 'data/studentInfo.csv' CSV HEADER

INSERT INTO students (id_student, gender, region, highest_education,
                      imd_band, age_band, disability)
SELECT DISTINCT ON (id_student)
       id_student::INT,
       gender,
       region,
       highest_education,
       NULLIF(imd_band, '?'),
       age_band,
       disability
FROM stg_student_info
ORDER BY id_student;

-- keep stg_student_info for now — we'll need final_result for registrations next


-- ---- registrations: dates from studentRegistration.csv + final_result from studentInfo ----
DROP TABLE IF EXISTS stg_registration;
CREATE TABLE stg_registration (
    code_module         TEXT,
    code_presentation   TEXT,
    id_student          TEXT,
    date_registration   TEXT,
    date_unregistration TEXT
);

\copy stg_registration FROM 'data/studentRegistration.csv' CSV HEADER

INSERT INTO registrations (id_student, code_module, code_presentation,
                           date_registration, date_unregistration, final_result)
SELECT r.id_student::INT,
       r.code_module,
       r.code_presentation,
       NULLIF(r.date_registration,   '?')::INT,
       NULLIF(r.date_unregistration, '?')::INT,
       i.final_result
FROM stg_registration r
JOIN stg_student_info i
  ON  i.id_student        = r.id_student
  AND i.code_module       = r.code_module
  AND i.code_presentation = r.code_presentation;

-- staging tables no longer needed
DROP TABLE stg_registration;
DROP TABLE stg_student_info;


-- ---- student_assessments: scores per student per assessment ----
DROP TABLE IF EXISTS stg_student_assessment;
CREATE TABLE stg_student_assessment (
    id_assessment  TEXT,
    id_student     TEXT,
    date_submitted TEXT,
    is_banked      TEXT,
    score          TEXT
);

\copy stg_student_assessment FROM 'data/studentAssessment.csv' CSV HEADER

INSERT INTO student_assessments (id_assessment, id_student,
                                 date_submitted, is_banked, score)
SELECT id_assessment::INT,
       id_student::INT,
       NULLIF(date_submitted, '?')::INT,
       is_banked::INT,
       NULLIF(score, '?')::NUMERIC
FROM stg_student_assessment;

DROP TABLE stg_student_assessment;

-- ---- vle_interactions: 10.6M rows, direct load with column mapping ----
\copy vle_interactions (code_module, code_presentation, id_student, id_site, activity_date, sum_click) FROM 'data/studentVle.csv' CSV HEADER