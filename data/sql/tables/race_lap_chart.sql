DROP TABLE IF EXISTS race_lap_chart;

CREATE TABLE race_lap_chart
(
    race_id CHAR(8) NOT NULL,
    no INTEGER NOT NULL,
    lap INTEGER NOT NULL,
    pos INTEGER NOT NULL,
    PRIMARY KEY (race_id, lap, pos),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    FOREIGN KEY (race_id, no) REFERENCES race_driver(race_id, no)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    UNIQUE (race_id, no, lap),
    CHECK (pos BETWEEN 1 and 26),
    CHECK (no BETWEEN 0 AND 25)
);

CREATE INDEX IF NOT EXISTS race_lap_chart_race_id_idx ON race_lap_chart (race_id);
CREATE INDEX IF NOT EXISTS race_lap_chart_no ON race_lap_chart (no);
CREATE INDEX IF NOT EXISTS race_lap_chart_laps ON race_lap_chart(race_id, no, lap);

