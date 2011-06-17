DROP TABLE IF EXISTS race_classification;

CREATE TABLE race_classification
(
    race_id CHAR(8) NOT NULL,
    pos INTEGER,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    nat CHAR(3) NOT NULL,
    entrant VARCHAR(50) NOT NULL,
    laps INTEGER NOT NULL,
    time TIME,
    gap VARCHAR(7),
    kph DECIMAL(6,3),
    best TIME,
    lap INTEGER,
    PRIMARY KEY (race_id, no),
    UNIQUE (race_id, pos),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (no BETWEEN 0 AND 25)
);

CREATE INDEX IF NOT EXISTS race_classification_race_id_idx
    ON race_classification(race_id);


