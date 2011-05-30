DROP VIEW IF EXISTS race_lap_xsec;

CREATE VIEW race_lap_xsec AS

SELECT race_id, lap,
MAX(CASE WHEN no =  1 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "1",
MAX(CASE WHEN no =  2 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "2",
MAX(CASE WHEN no =  3 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "3",
MAX(CASE WHEN no =  4 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "4",
MAX(CASE WHEN no =  5 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "5",
MAX(CASE WHEN no =  6 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "6",
MAX(CASE WHEN no =  7 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "7",
MAX(CASE WHEN no =  8 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "8",
MAX(CASE WHEN no =  9 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "9",
MAX(CASE WHEN no =  10 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "10",
MAX(CASE WHEN no =  11 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "11",
MAX(CASE WHEN no =  12 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "12",
MAX(CASE WHEN no =  14 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "14",
MAX(CASE WHEN no =  15 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "15",
MAX(CASE WHEN no =  16 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "16",
MAX(CASE WHEN no =  17 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "17",
MAX(CASE WHEN no =  18 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "18",
MAX(CASE WHEN no =  19 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "19",
MAX(CASE WHEN no =  20 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "20",
MAX(CASE WHEN no =  21 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "21",
MAX(CASE WHEN no =  22 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "22",
MAX(CASE WHEN no =  23 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "23",
MAX(CASE WHEN no =  24 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "24",
MAX(CASE WHEN no =  25 THEN
    (SELECT round(SUM(diff), 3) FROM race_lap_diff x WHERE x.lap<=y.lap AND x.no=y.no) ELSE NULL END) AS "25"
FROM race_lap_sec y
GROUP BY race_id, lap;
