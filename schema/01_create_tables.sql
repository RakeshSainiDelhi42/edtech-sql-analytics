DROP TABLE IF EXISTS vle_interactions, student_assessments, assessments,
                     registrations, students, courses CASCADE;



-- Course presentations: one run of a module
-- code_presentation: 2013J = starts Oct 2013, 2014B = starts Feb 2014
CREATE TABLE courses (
    code_module        VARCHAR(10) NOT NULL,
    code_presentation  VARCHAR(10) NOT NULL,
    length_days        INT NOT NULL,
    PRIMARY KEY (code_module, code_presentation)
);

-- One row per student: demographics only
CREATE TABLE students (
    id_student         INT PRIMARY KEY,
    gender             CHAR(1),
    region             VARCHAR(50),
    highest_education  VARCHAR(60),
    imd_band           VARCHAR(20),
    age_band           VARCHAR(20),
    disability         CHAR(1)
);

-- One row per student per course presentation (enrolment record)
CREATE TABLE registrations (
    id_student          INT NOT NULL REFERENCES students,
    code_module         VARCHAR(10) NOT NULL,
    code_presentation   VARCHAR(10) NOT NULL,
    date_registration   INT,
    date_unregistration INT,          -- NULL = never withdrew
    final_result        VARCHAR(20),  -- Pass / Fail / Withdrawn / Distinction
    PRIMARY KEY (id_student, code_module, code_presentation),
    FOREIGN KEY (code_module, code_presentation) REFERENCES courses
);

-- The assessments planned in each course
CREATE TABLE assessments (
    id_assessment      INT PRIMARY KEY,
    code_module        VARCHAR(10) NOT NULL,
    code_presentation  VARCHAR(10) NOT NULL,
    assessment_type    VARCHAR(10),   -- TMA / CMA / Exam
    date_due           INT,
    weight             NUMERIC(5,2),
    FOREIGN KEY (code_module, code_presentation) REFERENCES courses
);

-- Each student's score on each assessment
CREATE TABLE student_assessments (
    id_assessment  INT NOT NULL REFERENCES assessments,
    id_student     INT NOT NULL REFERENCES students,
    date_submitted INT,
    is_banked      INT,
    score          NUMERIC(5,2),
    PRIMARY KEY (id_assessment, id_student)
);

-- Daily clicks per student per VLE material (the 10M-row table)
CREATE TABLE vle_interactions (
    id_student         INT NOT NULL,
    code_module        VARCHAR(10) NOT NULL,
    code_presentation  VARCHAR(10) NOT NULL,
    id_site            INT NOT NULL,
    activity_date      INT NOT NULL,
    sum_click          INT NOT NULL,
    FOREIGN KEY (code_module, code_presentation) REFERENCES courses
);