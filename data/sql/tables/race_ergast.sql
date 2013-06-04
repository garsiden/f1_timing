DROP TABLE IF EXISTS race_ergast;

CREATE TABLE race_ergast
(
    rd INTEGER NOT NULL,
    date DATE NOT NULL,
    gp VARCHAR(25) NOT NULL,
    start_time_gmt TIME NOT NULL,
    PRIMARY KEY (rd),
    season INTEGER NOT NULL DEFAULT 0,
    circuit_id VARCHAR(25) NOT NULL
);
