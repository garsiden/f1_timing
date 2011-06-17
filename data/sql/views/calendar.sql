DROP VIEW IF EXISTS calendar;

CREATE VIEW calendar AS

SELECT rd, strftime('%d-%m-%Y', [date]) AS date, gp,
coalesce(strftime('%H:%M', [date] || 'T' || start_time_gmt, 'localtime'), 'TBA') AS start,
SUBSTR(id, 1, 3) AS id,
strftime('%Y', [date]) AS season
FROM race;

