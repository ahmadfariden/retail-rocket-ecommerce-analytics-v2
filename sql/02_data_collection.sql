CREATE OR REPLACE VIEW raw_events AS
    SELECT *, to_timestamp(timestamp / 1000) AS event_datetime
    FROM read_csv_auto('data/raw/events.csv');

CREATE OR REPLACE VIEW raw_category_tree AS
    SELECT * FROM read_csv_auto('data/raw/category_tree.csv');

CREATE OR REPLACE VIEW raw_item_properties AS
    SELECT *, to_timestamp(timestamp / 1000) AS property_datetime
    FROM read_csv_auto('data/raw/item_properties_part1.csv')
    UNION ALL
    SELECT *, to_timestamp(timestamp / 1000) AS property_datetime
    FROM read_csv_auto('data/raw/item_properties_part2.csv');

SELECT 'raw_events' AS source, COUNT(*) AS row_count FROM raw_events
UNION ALL
SELECT 'raw_category_tree', COUNT(*) FROM raw_category_tree
UNION ALL
SELECT 'raw_item_properties', COUNT(*) FROM raw_item_properties;