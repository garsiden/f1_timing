DROP VIEW IF EXISTS total_time_hms;

CREATE VIEW total_time_hms AS  

SELECT race_id, no, count(lap) as laps,
strftime('%H:%M.%f', sum([jtime])-0.5) AS total,
strftime('%H:%M.%f', avg([jtime])-0.5) AS avg,
strftime('%H:%M.%f', min([jtime])-0.5) AS fastest
FROM race_lap_jul
GROUP by race_id, no
ORDER BY race_id, laps DESC, total ASC;
