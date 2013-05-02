DROP VIEW IF EXISTS race_lap;

CREATE VIEW race_lap AS 

SELECT h.race_id, h.no, h.lap, h.time, c.pos
FROM race_history h, race_lap_chart c
WHERE h.race_id = c.race_id AND h.no = c.no AND h.lap = c.lap
ORDER BY h.race_id, h.no, c.lap;


