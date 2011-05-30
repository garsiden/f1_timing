DROP TABLE IF EXISTS race_history;

CREATE TABLE race_history
(
    race_id CHAR(8),
    no INTEGER,
    lap INTEGER,
    pit CHAR(1),
    time TIME,
--  PRIMARY KEY (race_id, no, lap),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    FOREIGN KEY (race_id, no) REFERENCES race_driver(race_id, no)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    CHECK (no BETWEEN 1 AND 25)
);

CREATE INDEX IF NOT EXISTS race_history_race_id_idx ON race_history(race_id);
