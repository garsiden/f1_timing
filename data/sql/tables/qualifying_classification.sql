DROP TABLE IF EXISTS qualifying_classification;

CREATE TABLE qualifying_classification
(
    race_id CHAR(8) NOT NULL,
    pos INTEGER,
    no INTEGER NOT NULL,
    q1_laps INTEGER,
    q1_time VARCHAR(8),
    q1_tod TIME,
    percent DECIMAL(6,3),
    q2_laps INTEGER,
    q2_time VARCHAR(8),
    q2_tod TIME,
    q3_laps INTEGER,
    q3_time VARCHAR(8),
    q3_tod TIME,
    PRIMARY KEY (race_id, no),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    UNIQUE (race_id, pos),
    CHECK (no BETWEEN 0 AND 25)
);

CREATE INDEX IF NOT EXISTS qualifying_classification_race_id_idx ON qualifying_classification(race_id);

