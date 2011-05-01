DROP TABLE IF EXISTS race_fastest_lap;

CREATE TABLE race_fastest_lap
(
    race_id CHAR(8) NOT NULL,
    pos INTEGER NOT NULL,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    nat CHAR(3) NOT NULL,
    entrant VARCHAR(255) NOT NULL,
    time TIME NOT NULL,
    on_lap INTEGER NOT NULL,
    gap TIME,
    kph DECIMAL(6,3) NOT NULL,
    time_of_day TIME NOT NULL,
    PRIMARY KEY (race_id, pos),
    UNIQUE (race_id, no),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (pos BETWEEN 1 AND 26),
    CHECK (no BETWEEN 1 AND 26)
);

CREATE INDEX IF NOT EXISTS race_fastest_lap_race_id_idx ON race_fastest_lap(race_id);