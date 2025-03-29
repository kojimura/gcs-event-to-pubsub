from flask import Flask, request
from google.cloud import pubsub_v1
import json
import os
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(os.environ["GCP_PROJECT"], os.environ["TOPIC_NAME"])

@app.route("/", methods=["POST"])
def receive_event():
    event = request.get_json()
    logging.info(f"Received CloudEvent: {json.dumps(event)}")

    try:
        name = event.get("name")
        bucket = event.get("bucket")
        if not name or not bucket:
            logging.warning("Missing name or bucket in event.")
            return "Invalid event", 400
    except Exception as e:
        logging.error(f"Error parsing event: {e}")
        return "Bad Request", 400

    data = json.dumps(event).encode("utf-8")
    publisher.publish(topic_path, data=data)
    logging.info(f"Published to Pub/Sub: {name}")

    return "", 204
