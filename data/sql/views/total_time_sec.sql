DROP VIEW IF EXISTS total_time_sec;

CREATE VIEW total_time_sec AS

SELECT race_id, no, count(no) AS laps, round(sum(secs), 3) AS total, avg(secs) AS avg
FROM race_lap_sec
GROUP BY race_id, no
ORDER BY race_id, laps DESC, total ASC;

