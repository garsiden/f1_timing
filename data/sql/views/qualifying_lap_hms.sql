DROP VIEW IF EXISTS qualifying_lap_hms;

CREATE VIEW qualifying_lap_hms AS

SELECT race_id, no, lap, time FROM qualifying_lap_time
ORDER BY race_id, no, lap;
