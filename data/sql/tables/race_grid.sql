DROP TABLE IF EXISTS race_grid;

CREATE TABLE race_grid
(
    race_id CHAR(8) NOT NULL,
    pos INTEGER NOT NULL,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    entrant VARCHAR(255) NOT NULL,
    time DATETIME,
    PRIMARY KEY (race_id, pos),
    UNIQUE (race_id, no),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (pos BETWEEN 0 AND 25),
    CHECK (no BETWEEN 1 AND 99)
);

CREATE INDEX IF NOT EXISTS race_grid_race_id_idx ON race_grid(race_id);
