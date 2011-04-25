DROP TABLE IF EXISTS race;

CREATE TABLE race
(
    id CHAR(8) NOT NULL PRIMARY KEY,
    round CHAR(2) NOT NULL,
    date DATE NOT NULL,
    location VARCHAR(255) NOT NULL,
    start_time_local DATETIME NOT NULL,
    start_time_gmt DATETIME NOT NULL,
    lap_km DECIMAL(4,3) NOT NULL,
    lap_mi DECIMAL(4,3) NOT NULL,
    laps INTEGER NOT NULL,
    UNIQUE (id, round)
);

CREATE INDEX IF NOT EXISTS idx_race_round ON race(round);
