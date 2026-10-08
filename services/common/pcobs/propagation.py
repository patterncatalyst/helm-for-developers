"""Carry W3C trace context across Kafka.

HTTP clients and servers propagate `traceparent` for you. A Kafka record is just
bytes, so the producer injects the active context into the record headers and the
consumer extracts it; without that the consumer starts a disconnected trace.
"""
from __future__ import annotations

from collections.abc import Iterable

from opentelemetry import propagate
from opentelemetry.context import Context


def inject_headers(existing: Iterable[tuple[str, bytes]] | None = None) -> list[tuple[str, bytes]]:
    """Return Kafka headers carrying the active trace context."""
    headers = list(existing or [])
    carrier: dict[str, str] = {}
    propagate.inject(carrier)
    headers.extend((key, value.encode("utf-8")) for key, value in carrier.items())
    return headers


def extract_context(headers: Iterable[tuple[str, bytes]] | None) -> Context:
    """Rebuild the producer's context from a consumed record's headers."""
    carrier = {
        key: value.decode("utf-8") if isinstance(value, (bytes, bytearray)) else str(value)
        for key, value in headers or []
    }
    return propagate.extract(carrier)
