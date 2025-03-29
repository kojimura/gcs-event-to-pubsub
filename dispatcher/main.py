from flask import Flask, request
import base64
import json
import os
import logging
import requests
from google.auth import default
from google.auth.transport.requests import Request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

def run_job(job_name, region, message_payload):
    credentials, _ = default()
    credentials.refresh(Request())

    project = os.environ["GOOGLE_CLOUD_PROJECT"]
    url = f"https://{region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/{project}/jobs/{job_name}:run"

    headers = {
        "Authorization": f"Bearer {credentials.token}",
        "Content-Type": "application/json"
    }

    body = {
        "overrides": {
            "containerOverrides": [
                {
                    "name": job_name,
                    "env": [
                        {
                            "name": "PUBSUB_MSG",
                            "value": message_payload
                        }
                    ]
                }
            ]
        }
    }

    response = requests.post(url, headers=headers, json=body)
    logging.info(f"Run job response: {response.status_code} {response.text}")
    return response.status_code

@app.route("/", methods=["POST"])
def handle_pubsub():
    envelope = request.get_json()
    if not envelope or 'message' not in envelope:
        logging.warning("Invalid Pub/Sub message format")
        return "", 400

    message = envelope['message']
    data = message.get('data')

    message = envelope['message']
    data = message.get('data')

    if data:
        try:
            decoded = base64.b64decode(data).decode('utf-8', errors='replace')
        except Exception as e:
            logging.error(f"Error decoding message: {e}")
            decoded = "[invalid message]"
    else:
        decoded = "[no message]"

    run_job(os.environ['JOB_NAME'], os.environ['JOB_REGION'], decoded)
    return "", 204