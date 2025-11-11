import argparse
import logging
import os
import signal
import sys

from confluent_kafka import KafkaError, KafkaException

from common import ClickHouseWriter, build_consumer
from parsers import PARSERS, BaseParser


logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(message)s",
)
logger = logging.getLogger(__name__)


def resolve_parser(parser_name: str | None = None) -> BaseParser:
    parser_name = parser_name or os.getenv("PARSER")
    if not parser_name:
        raise RuntimeError(
            "Parser not specified. Provide --parser argument or set PARSER environment variable."
        )
    parser_cls = PARSERS.get(parser_name.lower())
    if not parser_cls:
        raise RuntimeError(f"Unsupported parser '{parser_name}'. Available: {', '.join(PARSERS.keys())}")
    return parser_cls()


def consume(parser: BaseParser) -> None:
    topic = parser.topic()
    group_id = parser.group_id()
    writer = ClickHouseWriter()
    consumer = build_consumer(group_id)
    consumer.subscribe([topic])
    logger.info("Parser '%s' consuming topic '%s' with group '%s'", parser.name, topic, group_id)

    running = True

    def _shutdown(signum, frame):
        nonlocal running
        running = False
        logger.info("Signal %s received, shutting down", signum)

    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, _shutdown)

    try:
        while running:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                logger.error("Kafka error: %s", msg.error())
                continue
            try:
                event = parser.prepare_event(msg)
                writer.insert_event(event)
                consumer.commit(msg)
                logger.debug("Stored %s event %s", event["source"], event["id"])
            except (KafkaException, RuntimeError, ValueError) as err:
                logger.warning("Failed to process message: %s", err)
    finally:
        consumer.close()
        logger.info("Kafka consumer closed")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Four Keys ClickHouse parser worker.")
    parser.add_argument(
        "-p",
        "--parser",
        choices=sorted(PARSERS.keys()),
        help="Parser to run (overrides PARSER env var).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    parser = resolve_parser(args.parser)
    consume(parser)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("Interrupted by user, exiting")
        sys.exit(0)
