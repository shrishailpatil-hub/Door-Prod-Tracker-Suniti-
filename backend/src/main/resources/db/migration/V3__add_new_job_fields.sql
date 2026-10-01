ALTER TABLE jobs 
    ADD COLUMN fr VARCHAR(255),
    ADD COLUMN delivery_address VARCHAR(255),
    ADD COLUMN po_no VARCHAR(255),
    ADD COLUMN gst_no VARCHAR(255),
    ADD COLUMN po_date DATE,
    ADD COLUMN order_date DATE,
    ADD COLUMN delivery_date DATE,
    ADD COLUMN doors VARCHAR(255),
    ADD COLUMN door_leaf VARCHAR(255),
    ADD COLUMN colour_shade VARCHAR(255),
    ADD COLUMN vehicle_details VARCHAR(255);
