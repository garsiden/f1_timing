DROP TABLE IF EXISTS qualifying_speed_trap;

CREATE TABLE qualifying_speed_trap
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
    CHECK (pos BETWEEN 1 and 26),
    CHECK (no BETWEEN 1 AND 26)
);

CREATE INDEX IF NOT EXISTS qualifying_speed_trap_race_id_idx ON qualifying_speed_trap (race_id);
CREATE INDEX IF NOT EXISTS qualifying_speed_trap_pos_idx ON qualifying_speed_trap (pos);
CREATE INDEX IF NOT EXISTS qualifying_speed_trap_no_idx ON qualifying_speed_trap (no);
