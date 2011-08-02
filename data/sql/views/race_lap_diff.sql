DROP VIEW IF EXISTS race_lap_diff;

CREATE VIEW race_lap_diff AS

SELECT race_id, no, lap,
    (SELECT round(avg,3) FROM total_time_sec WHERE race_id='hun-2011' limit 1) - secs AS diff
FROM race_lap_sec
WHERE race_id='hun-2011';

