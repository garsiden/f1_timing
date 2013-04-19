DROP VIEW IF EXISTS current_race;

CREATE VIEW current_race AS
    SELECT rd, SUBSTR(id, 1, 3) AS id, SUBSTR(id, 5, 4) AS season, gp AS page
    FROM race
    WHERE "date" = (COALESCE(
            (SELECT MAX("date")
                FROM race
                WHERE CASE gp 
                    WHEN 'Monaco' THEN DATE("date",'-3 days')
                    ELSE DATE("date",'-2 days')
                END <= DATE('now')),
            (SELECT MIN("date") FROM race)
    ));
