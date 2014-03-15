DROP TABLE IF EXISTS race_pit_stop_summary;

CREATE TABLE race_pit_stop_summary
(
    race_id CHAR(8) NOT NULL,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    entrant VARCHAR(255) NOT NULL,
    lap INTEGER NOT NULL,
    time_of_day TIME NOT NULL,
    stop INTEGER NOT NULL,
    duration TIME NOT NULL,
    total_time TIME NOT NULL,
    PRIMARY KEY (race_id, no, stop),
    UNIQUE (race_id, no, lap),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (no BETWEEN 1 AND 99)
);

CREATE INDEX IF NOT EXISTS race_pit_stop_summary_race_id_idx ON race_pit_stop_summary(race_id);
