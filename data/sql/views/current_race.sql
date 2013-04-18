DROP VIEW IF EXISTS current_race2;

CREATE VIEW current_race2 AS

SELECT rd, id
    FROM race
    WHERE "date" = (COALESCE(
            (SELECT MAX("date")
                FROM race
                WHERE CASE gp 
                    WHEN 'Monaco' THEN DATE("date",'-3 days')
                    ELSE DATE("date",'-2 days')
                END <= DATE()),
            (SELECT MIN("date") FROM race)
    ));
