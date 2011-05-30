DROP VIEW IF EXISTS race_lap_jul;

CREATE VIEW race_lap_jul AS 

SELECT race_id, no, lap, pit, julianday([time]) - 2451544.5 AS jtime
FROM race_lap_hms;

