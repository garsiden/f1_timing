DROP TABLE IF EXISTS qualifying_lap_time;

CREATE TABLE qualifying_lap_time
(
    race_id CHAR(8) NOT NULL,
    no INTEGER NOT NULL,
    lap INTEGER NOT NULL,
    pit CHAR(1),
    time TIME NOT NULL,
    PRIMARY KEY (race_id, no, lap),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    FOREIGN KEY (race_id, no) REFERENCES qualifying_driver(race_id, no)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (no BETWEEN 0 AND 25)
);

CREATE INDEX IF NOT EXISTS qualifying_lap_time_race_id_idx ON qualifying_lap_time(race_id);
CREATE INDEX IF NOT EXISTS qualifying_lap_time_race_id_no_idx ON qualifying_lap_time(race_id, no);
