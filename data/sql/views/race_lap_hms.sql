DROP VIEW IF EXISTS race_lap_hms;

CREATE VIEW race_lap_hms AS

SELECT race_id, no, lap, pit, [time] FROM race_history WHERE lap = 1
UNION ALL
SELECT race_id, no, lap, pit, [time] FROM race_lap_analysis WHERE lap > 1
ORDER BY race_id, no, lap;
