DROP VIEW race_id IF EXISTS;

CREATE VIEW race_id AS
    SELECT rd, SUBSTR(id,1,3) AS id, SUBSTR(id, 5,4) AS season, gp AS page
    FROM race;
