DROP VIEW IF EXISTS total_time_jul;

CREATE VIEW total_time_jul AS  

SELECT race_id, no, count(lap) as laps,
sum(jtime) AS total,
avg(jtime) AS avg,
min(jtime) AS fastest
FROM race_lap_jul
GROUP by race_id, no
ORDER BY race_id, laps DESC, total ASC;
