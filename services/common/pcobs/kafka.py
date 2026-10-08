"""aiokafka helpers: JSON values, trace context in headers."""
from __future__ import annotations

import json
from typing import Any

from aiokafka import AIOKafkaConsumer, AIOKafkaProducer

from .propagation import inject_headers


async def make_producer(bootstrap: str) -> AIOKafkaProducer:
    producer = AIOKafkaProducer(
        bootstrap_servers=bootstrap,
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        key_serializer=lambda k: k.encode("utf-8") if k else None,
        enable_idempotence=True,
    )
    await producer.start()
    return producer


async def make_consumer(bootstrap: str, topic: str, group_id: str) -> AIOKafkaConsumer:
    consumer = AIOKafkaConsumer(
        topic,
        bootstrap_servers=bootstrap,
        group_id=group_id,
        value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        auto_offset_reset="earliest",
    )
    await consumer.start()
    return consumer


async def publish_event(producer: AIOKafkaProducer, topic: str, key: str, value: dict[str, Any]) -> None:
    """Send a JSON event with the current trace context in its headers."""
    await producer.send_and_wait(topic, key=key, value=value, headers=inject_headers())
