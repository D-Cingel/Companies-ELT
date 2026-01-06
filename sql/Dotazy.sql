// Zakladne prikazy
USE DATABASE PANTHER_DB;
USE WAREHOUSE PANTHER_WH;
CREATE SCHEMA projekt;
USE SCHEMA projekt;

// Tvorba a naplnenie staging tabulky
CREATE OR REPLACE TABLE companies_staging AS
SELECT * FROM FREE_COMPANY_DATASET.PUBLIC.FREECOMPANYDATASET;

// Tvorba a naplnenie tabulky dimenzie info SCD 1
CREATE OR REPLACE TABLE dim_info AS (
    SELECT
    ROW_NUMBER() OVER (ORDER BY id) AS info_id,
    id AS pld_id,
    name,
    COALESCE(industry, 'Unknown') AS industry,
    COALESCE(website, 'Unknown') AS website,
    linkedin_url
    FROM companies_staging
);

// Tvorba a naplnenie tabulky dimenzie locality SCD 0
CREATE OR REPLACE TABLE dim_loc (
    loc_id NUMBER(8,0) PRIMARY KEY AUTOINCREMENT,
    locality VARCHAR(50)
);
INSERT INTO dim_loc (locality)
SELECT DISTINCT
    COALESCE(locality, 'Unknown') AS locality
FROM companies_staging;

// Tvorba a naplnenie tabulky dimenzie region SCD 0
CREATE OR REPLACE TABLE dim_reg (
    reg_id NUMBER(8,0) PRIMARY KEY AUTOINCREMENT,
    region VARCHAR(50)
);
INSERT INTO dim_reg (region)
SELECT DISTINCT
    COALESCE(region, 'Unknown') AS region
FROM companies_staging;

// Tvorba a naplnenie tabulky dimenzie country SCD 0
CREATE OR REPLACE TABLE dim_cnt (
    cnt_id NUMBER(8,0) PRIMARY KEY AUTOINCREMENT,
    country VARCHAR(50)
);
INSERT INTO dim_cnt (country)
SELECT DISTINCT
    COALESCE(country, 'Unknown') AS country
FROM companies_staging;

// Tvorba a naplnenie tabulky dimenzie size SCD 0
CREATE OR REPLACE TABLE dim_size (
    size_id NUMBER(8,0) PRIMARY KEY AUTOINCREMENT,
    size VARCHAR(11)
);
INSERT INTO dim_size (size)
SELECT DISTINCT
    COALESCE(size, 'Unknown') AS size
FROM companies_staging;

// Tvorba a naplnenie tabulky faktov
CREATE OR REPLACE TABLE fact_companies AS (
    SELECT
    ROW_NUMBER() OVER (ORDER BY id) AS id_comp,
    i.info_id,
    COALESCE(cp.founded, ROUND(AVG(cp.founded) OVER (), 0)) AS founded,                                 // Nahradenie NULL hodnot priemernym rokom
    l.loc_id,
    r.reg_id,
    c.cnt_id,
    s.size_id,
    COUNT(*) OVER (PARTITION BY cp.country, cp.founded) AS companies_founded_in_year,                   // Firmy zalozene v danom roku
    ROW_NUMBER() OVER (PARTITION BY cp.country ORDER BY cp.founded) AS company_age_rank_in_country      // Poradie firiem v statoch podla veku
    FROM companies_staging cp
    JOIN dim_info i ON cp.id = i.pld_id
    JOIN dim_loc l ON cp.locality = l.locality
    JOIN dim_reg r ON cp.region = r.region
    JOIN dim_cnt c ON cp.country = c.country
    JOIN dim_size s ON cp.size = s.size
);

DROP TABLE companies_staging;
