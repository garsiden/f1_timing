DROP TABLE IF EXISTS race;

CREATE TABLE race
(
    id CHAR(8) NOT NULL,
    rd CHAR(2) NOT NULL,
    date DATE NOT NULL,
    gp VARCHAR(25) NOT NULL,
    location VARCHAR(100) NOT NULL,
    start_time_local TIME NOT NULL,
    start_time_gmt TIME NOT NULL,
    lap_km DECIMAL(4,3) NOT NULL,
    lap_mi DECIMAL(4,3) NOT NULL,
    laps INTEGER NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (id, rd)
);
