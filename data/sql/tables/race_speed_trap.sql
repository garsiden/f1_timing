DROP TABLE IF EXISTS race_speed_trap;

CREATE TABLE race_speed_trap
(
    race_id CHAR(8) NOT NULL,
    pos INTEGER NOT NULL,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    kph DECIMAL(4,1) NOT NULL,
    time_of_day TIME NOT NULL,
    PRIMARY KEY (race_id, pos),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    UNIQUE (race_id, no),
    CHECK (pos BETWEEN 0 and 25),
    CHECK (no BETWEEN 1 AND 99)
);

CREATE INDEX IF NOT EXISTS race_speed_trap_race_id_idx ON race_speed_trap (race_id);
