DROP TABLE IF EXISTS practice_2_lap_time;

CREATE TABLE practice_2_lap_time
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
    FOREIGN KEY (race_id, no) REFERENCES practice_2_driver(race_id, no)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (no BETWEEN 1 AND 99)
);

CREATE INDEX IF NOT EXISTS practice_2_lap_time_race_id_idx ON practice_2_lap_time(race_id);
CREATE INDEX IF NOT EXISTS practice_2_lap_time_race_id_no_idx ON practice_2_lap_time(race_id, no);
