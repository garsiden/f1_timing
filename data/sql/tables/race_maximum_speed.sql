DROP TABLE IF EXISTS race_maximum_speed;

CREATE TABLE race_maximum_speed
(
    race_id CHAR(8) NOT NULL,
    speedtrap INTEGER NOT NULL,
    pos INTEGER NOT NULL,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    kph DECIMAL(4,1) NOT NULL,
    PRIMARY KEY (race_id, speedtrap, pos),
    UNIQUE (race_id, speedtrap, no),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
    CHECK (speedtrap IN(1, 2, 3)),
    CHECK (pos BETWEEN 0 AND 25),
    CHECK (no BETWEEN 0 AND 25)
);

CREATE INDEX IF NOT EXISTS race_maximum_speed_race_id_idx ON race_maximum_speed(race_id);
