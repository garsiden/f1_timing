DROP VIEW IF EXISTS race_lap_sec;

CREATE VIEW race_lap_sec AS 

SELECT race_id, no, lap, pit, round(jtime * 86400.0, 3) AS secs
FROM race_lap_jul;

