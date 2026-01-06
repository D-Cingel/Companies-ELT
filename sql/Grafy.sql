// Pocet firiem podla priemyslu
SELECT COUNT(f.id_comp) AS companies, i.industry FROM fact_companies f JOIN dim_info i ON f.info_id = i.info_id GROUP BY i.industry HAVING i.industry != 'Unknown' ORDER BY i.industry ASC

// Top 10 krajin s najvacsim poctom firiem
SELECT COUNT(f.id_comp) AS companies, c.country FROM fact_companies f JOIN dim_cnt c ON f.cnt_id = c.cnt_id GROUP BY c.country ORDER BY companies DESC LIMIT 10

// Pocet firiem zalozenych za rok 2006-2024
SELECT COUNT(f.id_comp) AS companies, f.founded AS rok FROM fact_companies f WHERE f.founded BETWEEN 2006 AND 2024 GROUP BY rok

// 20 najstarsich firiem
SELECT i.name, i.industry, (2026 - f.founded) AS vek FROM fact_companies f JOIN dim_info i ON f.info_id = i.info_id ORDER BY vek DESC LIMIT 20

// Pocet firiem podla velkosti
SELECT s.size AS size, COUNT(f.id_comp) AS companies FROM fact_companies f JOIN dim_size s ON f.size_id = s.size_id GROUP BY s.size;
