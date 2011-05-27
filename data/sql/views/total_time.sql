DROP VIEW IF EXISTS total_time;

CREATE VIEW total_time AS

SELECT count(no) AS laps, no,
    round(sum((julianday([time]) - 2451544.5)*86400.0/58), 3) AS total 
FROM race_lap_analysis
WHERE race_id='tur-2011' AND lap > 1
GROUP BY no
ORDER BY laps DESC, total;

