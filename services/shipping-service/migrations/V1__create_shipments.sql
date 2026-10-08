-- Shipments owned by this service. order_id is a plain value, not a foreign key:
-- the order lives in another service's schema.
CREATE TABLE shipments (
    id          BIGSERIAL PRIMARY KEY,
    order_id    BIGINT       NOT NULL,
    address     VARCHAR(255) NOT NULL,
    status      VARCHAR(32)  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_shipments_order_id ON shipments (order_id);
