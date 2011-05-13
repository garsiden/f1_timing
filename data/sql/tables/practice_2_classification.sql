DROP TABLE IF EXISTS practice_2_classification;

CREATE TABLE practice_2_classification
(
    race_id CHAR(8) NOT NULL,
    pos INTEGER NOT NULL,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    nat CHAR(3) NOT NULL,
    entrant VARCHAR(255) NOT NULL,
    time TIME,
    laps INTEGER NOT NULL,
    gap TIME,
    kph DECIMAL(6,3),
    time_of_day TIME,
    PRIMARY KEY (race_id, pos),
    UNIQUE (race_id, no),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (pos BETWEEN 1 AND 25),
    CHECK (no BETWEEN 1 AND 25)
);

CREATE INDEX IF NOT EXISTS practice_2_classification_race_id_idx ON practice_2_classification(race_id);
