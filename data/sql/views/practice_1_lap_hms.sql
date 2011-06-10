DROP VIEW IF EXISTS practice_1_lap_hms;

CREATE VIEW practice_1_lap_hms AS

SELECT race_id, no, lap, time FROM practice_1_lap_time
ORDER BY race_id, no, lap;
