DROP TABLE IF EXISTS qualifying_sector;

CREATE TABLE qualifying_sector
(
    race_id CHAR(8) NOT NULL
    REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
    pos INTEGER NOT NULL,
    no INTEGER NOT NULL,
    driver VARCHAR(25) NOT NULL,
    sector INTEGER NOT NULL,
    time DATETIME NOT NULL,
    UNIQUE (race_id, no, sector)
);

CREATE INDEX IF NOT EXISTS qualifying_sector_race_id_idx ON qualifying_sector (race_id);
CREATE INDEX IF NOT EXISTS qualifying_sector_pos_idx ON qualifying_sector (pos);
CREATE INDEX IF NOT EXISTS qualifying_sector_no_idx ON qualifying_sector (no);
