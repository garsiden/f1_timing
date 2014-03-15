DROP TABLE IF EXISTS qualifying_best_sector_time;

CREATE TABLE qualifying_best_sector_time
(
    race_id CHAR(8) NOT NULL,
    sector INTEGER NOT NULL,
    pos INTEGER NOT NULL,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    time DATETIME NOT NULL,
    PRIMARY KEY (race_id, sector, pos),
    UNIQUE (race_id, sector, no),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (sector IN(1, 2, 3)),
    CHECK (pos BETWEEN 0 AND 25),
    CHECK (no BETWEEN 1 AND 99)
);

CREATE INDEX IF NOT EXISTS qualifying_best_sector_time_race_id_idx ON qualifying_best_sector_time (race_id);
