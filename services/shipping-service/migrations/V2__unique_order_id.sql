-- At most one shipment per order, so a redelivered request cannot create a second one.
DROP INDEX IF EXISTS idx_shipments_order_id;
ALTER TABLE shipments ADD CONSTRAINT uq_shipments_order_id UNIQUE (order_id);
