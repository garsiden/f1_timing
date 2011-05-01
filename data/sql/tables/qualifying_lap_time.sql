DROP TABLE IF EXISTS qualifying_lap_time;

CREATE TABLE qualifying_lap_time
(
    race_id CHAR(8) NOT NULL,
    no INTEGER NOT NULL,
--    pit CHAR(1),
    lap INTEGER NOT NULL,
    time TIME NOT NULL,
    PRIMARY KEY (race_id, no, lap),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (no BETWEEN 1 AND 26)
);

CREATE INDEX IF NOT EXISTS qualifying_lap_time_race_id_idx ON qualifying_lap_time(race_id);