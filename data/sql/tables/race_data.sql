DROP TABLE IF EXISTS race_data;

CREATE TABLE race_data
(
    race_id CHAR(8) NOT NULL,
    fuel_consumption_kg DECIMAL(3,2) NOT NULL,
    fuel_effect_10kg DECIMAL(3,2) NOT NULL,
    fuel_total_kg DECIMAL(4,1) NOT NULL,
    PRIMARY KEY (race_id)
    FOREIGN KEY (race_id) REFERENCES race(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
);
