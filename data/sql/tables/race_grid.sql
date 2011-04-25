DROP TABLE IF EXISTS race_grid;

CREATE TABLE race_grid
(
    race_id CHAR(8) NOT NULL,
    pos INTEGER NOT NULL,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    entrant VARCHAR(255) NOT NULL,
    time DATETIME,
    PRIMARY KEY (race_id, pos),
    UNIQUE (race_id, no),
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON DELETE CASCADE ON UPDATE CASCADE
);
