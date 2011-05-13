DROP TABLE IF EXISTS race_lap_analysis;

CREATE TABLE race_lap_analysis
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
    FOREIGN KEY (race_id, no) REFERENCES race_driver(race_id, no)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (no BETWEEN 1 AND 25)
);

CREATE INDEX IF NOT EXISTS race_lap_analysis_race_id_idx ON race_lap_analysis(race_id);
