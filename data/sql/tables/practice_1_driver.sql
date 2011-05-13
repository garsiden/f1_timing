DROP TABLE IF EXISTS practice_1_driver;

CREATE TABLE practice_1_driver
(
    race_id CHAR(8) NOT NULL,
    no INTEGER NOT NULL,
    name VARCHAR(25) NOT NULL,
    PRIMARY KEY(race_id, no),
    UNIQUE (race_id, name),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (no BETWEEN 0 AND 25)
);

CREATE INDEX IF NOT EXISTS practice_1_driver_race_id_idx ON practice_1_driver(race_id);
