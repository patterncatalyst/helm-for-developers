"""pcobs: observability and Kafka plumbing shared by every service.

Typical startup:

    from pcobs import logging as pclog, otel
    pclog.configure()
    otel.setup("shipping-service")
    otel.instrument_fastapi(app)
"""
