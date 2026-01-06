# ELT proces datasetu Free Company
Tento repozitár predstavuje našu implementáciu ELT procesu v Snowflake a vytvorenie dátového skladu so schémou Star Schema. Projekt pracuje s **Free Company** datasetom. Projekt sa zameriava na analýzu firiem zahrnutých v datasete.
## 1. Úvod a popis zdrojových dát
Daný dataset sme vybrali lebo aspoň zdanlivo vyzeral použiteľne na zadaný projekt a zdalo sa nám, že ho nikto iný nepoužil. 
Zdrojové dáta pochádzajú z datasetu dostupného na [Snowflake marketplace](https://app.snowflake.com/marketplace/listing/GZSTZRRVYL2/people-data-labs-free-company-dataset?search=free%20companies). Dataset obsahuje jednu tabuľku: 
+ `FREECOMPANYDATASET` - všetky dáta o firmách 
Účelom ELT procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre viacdimenzionálnu analýzu.
### 1.1 Dátová architektúra
### ERD diagram
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na entitno-relačnom diagrame (ERD):
![Obrázok 1 Entitno-relačná schéma Free Company](/img/erd_cingel_matusik.png)
## 2. Návrh dimenzionálneho modelu
V ukážke bola navrhnutá schéma hviezdy (star schema) podľa Kimballovej metodológie, ktorá obsahuje 1 tabuľku faktov `fact_companies`, ktorá je prepojená s nasledujúcimi 5 dimenziami: 
+ `dim_info` - Obsahuje väčšinu dát o firmách (pôvodné id, názov, priemysel, webstránka, linkedin url) 
+ `dim_size` - Obsahuje rozmedzia počtu zamestnancov
+ `dim_loc` - Obsahuje lokality 
+ `dim_reg` - Obsahuje regióny  
+ `dim_cnt` - Obsahuje krajiny 
Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.
![Obrázok 2 Schéma hviezdy pre Free Company](/img/star_schema_cingel_matusik.png)
## 3. ELT proces v Snowflake
ETL proces pozostáva z troch hlavných fáz: extrahovanie (Extract), načítanie (Load) a transformácia (Transform). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.
### 3.1 Extract (Extrahovanie dát)
Dáta boli importované z databázy `FREE_COMPANY_DATASET` a schémy `PUBLIC`. 
Nasledovný kód bol použitý na vytvorenie staging tabulky: 
```
CREATE OR REPLACE TABLE companies_staging AS
SELECT * FROM FREE_COMPANY_DATASET.PUBLIC.FREECOMPANYDATASET;
```
### 3.2 Load (Načítanie dát)
Tabuľky faktov a dimenzií boli naplenené nasledovným kódom:
```
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
```
### 3.3 Transform
Zbavili sme sa hodnôt `null` pomocou **COALESCE**, ktorý ich nahradil hodnotou `"Uknown"` v tabuľkách dimenzií. V tabuľke faktov sme použili **COALESCE** na stĺpec `founded` aby `null` hodnoty zmenil na priemer daného stĺpca: 
```
COALESCE(cp.founded, ROUND(AVG(cp.founded) OVER (), 0)) AS founded
```
Použili sme nasledovné window functions:
+ na zistenie počtu firiem založených v danom roku:
```
COUNT(*) OVER (PARTITION BY cp.country, cp.founded) AS companies_founded_in_year
```
+ na získanie poradia firiem v štátoch podľa veku:
```
ROW_NUMBER() OVER (PARTITION BY cp.country ORDER BY cp.founded) AS company_age_rank_in_country
```
+ na vytvorenie id vo formáte NUMBER: 
```
ROW_NUMBER() OVER (ORDER BY id) AS info_id
```
Každá tabuľka dimenzií, s výnimkou `dim_info`, používa SCD 0. Tabuľka `dim_info` používa SCD 1, kedže sme usúdili, že nám postačia aktuálne informácie o firmách.
## 4. Vizualizácia dát
Dashboard obsahuje `5 vizualizácií`, ktoré poskytujú prehľad informácií o firmách za určitých podmienok.
![Obrázok 3 Dashboard Free Company datasetu](/img/companies_dashboard_cingel_matusik.png)
### Graf 1 - Počet firiem podľa priemyslu
Ukazuje počet a rozdelenie firiem do zadaných priemyslov (okrem `Unknown`). Graf ukazuje, že najviac firiem patrí do priemyslu `construction`.
```
SELECT COUNT(f.id_comp) AS companies, i.industry FROM fact_companies f JOIN dim_info i ON f.info_id = i.info_id GROUP BY i.industry HAVING i.industry != 'Unknown' ORDER BY i.industry ASC;
```
### Graf 2 - Top 10 krajín s najväčším počtom firiem
Zobrazuje 10 krajín s najväčším počtom firiem, a počet firiem. Graf ukazuje, napríklad obrovský rozdiel medzi počtom firiem v `Spojených Štátoch` a `Spojeným Kráľovstvom`.
```
SELECT COUNT(f.id_comp) AS companies, c.country FROM fact_companies f JOIN dim_cnt c ON f.cnt_id = c.cnt_id GROUP BY c.country ORDER BY companies DESC LIMIT 10;
```
### Graf 3 - Počet firiem firem založených za rok 2006-2024
Zobrazuje koľko firiem bolo založených za rok, medzi rokmi 2006 a 2024 (staršie roky nie sú zobrazené kvôli tomu že 2005 je priemerný rok založenia všetkých firiem, ktorý bol použitý na nahradenie hodnoty `null`).
```
SELECT COUNT(f.id_comp) AS companies, f.founded AS rok FROM fact_companies f WHERE f.founded BETWEEN 2006 AND 2024 GROUP BY rok;
```
### Graf 4 - 20 najstarších firiem
Zobrazuje 20 najstarších firiem, ich vek a do akého priemyslu patria.
```
SELECT i.name, i.industry, (2026 - f.founded) AS vek FROM fact_companies f JOIN dim_info i ON f.info_id = i.info_id ORDER BY vek DESC LIMIT 20;
```
### Graf 5 - Pocet firiem podla velkosti
Zobrazuje rozdeliene firiem podľa rozmedzia počtu zamestnancov.
```
SELECT s.size AS size, COUNT(f.id_comp) AS companies FROM fact_companies f JOIN dim_size s ON f.size_id = s.size_id GROUP BY s.size;
```
## Autori:
- Dominik Cingel
- Adrián Matušík
