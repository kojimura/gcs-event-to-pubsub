# gcs-event-to-pubsub

Cloud Storage to Cloud Run Job: Event-Driven Processing Pipeline

## Overview

This project implements a fully event-driven pipeline on Google Cloud that reacts to file uploads in a Cloud Storage bucket and triggers a long-running Cloud Run Job accordingly.

## Architecture

Cloud Storage(upload file) -> Eventarc Trigger(storage) -> Cloud Run(gcs-receiver) -> Pub/Sub(long-task-topic) -> Eventarc Trigger(pubsub) -> Cloud Run(dispatcher) -> Cloud Run Job(worker-job)

## Directory Structure
```text
gcs-event-to-job/
├── dispatcher/           # Cloud Run service that launches the job
│   ├── main.py           # Flask app to receive and dispatch Pub/Sub
│   ├── requirements.txt
│   └── Dockerfile
├── gcs-receiver/         # Cloud Run service that receives Cloud Storage events
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── worker-job/           # Cloud Run Job that does the long-running task
│   ├── main.py           # Sleep duration is based on filename
│   ├── requirements.txt
│   └── Dockerfile
```

## Key Technologies Used

- **Cloud Storage**: triggers on file upload
- **Eventarc**: routes events to services (receiver and dispatcher)
- **Pub/Sub**: message queue between receiver and dispatcher
- **Cloud Run**: used for short-lived `receiver` and `dispatcher`
- **Cloud Run Job**: used for long-running background processing
- **Flask + Gunicorn**: lightweight web servers

# Set Environment Variables
```
export REGION=asia-northeast1
export TOPIC_NAME=long-task-topic
export BUCKET_NAME=your-bucket-name
```

# Create Pub/Sub Topic
```
gcloud pubsub topics create $TOPIC_NAME || echo "Topic already exists"
```

# Build & Create Cloud Run Job
```
cd worker-job
gcloud builds submit --tag gcr.io/$(gcloud config get-value project)/worker-job
gcloud run jobs create worker-job \
  --source . \
  --region=$REGION \
  --memory=512Mi
```

# Deploy gcs-receiver
```
cd ../gcs-receiver
gcloud run deploy gcs-receiver \
  --source . \
  --region=$REGION \
  --memory=512Mi \
  --set-env-vars TOPIC_NAME=$TOPIC_NAME,GCP_PROJECT=$(gcloud config get-value project) \
  --no-allow-unauthenticated
```

# Deploy dispatcher
```
cd ../dispatcher
gcloud run deploy dispatcher \
  --source . \
  --region=$REGION \
  --memory=512Mi \
  --set-env-vars JOB_NAME=worker-job,JOB_REGION=$REGION,GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project) \
  --no-allow-unauthenticated
```

# Create Eventarc Triggers
# GCS to gcs-receiver
```
gcloud eventarc triggers create gcs-to-pubsub-trigger \
  --location=$REGION \
  --destination-run-service=gcs-receiver \
  --destination-run-region=$REGION \
  --event-filters="type=google.cloud.storage.object.v1.finalized" \
  --event-filters="bucket=$BUCKET_NAME" \
  --service-account=$(gcloud projects describe $(gcloud config get-value project) --format="value(projectNumber)")-compute@developer.gserviceaccount.com
```

# Pub/Sub to dispatcher
```
gcloud eventarc triggers create pubsub-to-dispatcher \
  --location=$REGION \
  --destination-run-service=dispatcher \
  --destination-run-region=$REGION \
  --transport-topic=$TOPIC_NAME \
  --event-filters="type=google.cloud.pubsub.topic.v1.messagePublished" \
  --service-account=$(gcloud projects describe $(gcloud config get-value project) --format="value(projectNumber)")-compute@developer.gserviceaccount.com
```

# Test Trigger
```
echo "test" > sleep_1min.txt
gsutil cp sleep_1min.txt gs://$BUCKET_NAME

# View Logs
# gcs-receiver logs
```
gcloud run services logs read gcs-receiver --region=$REGION --limit=50
```

# dispatcher logs
```
gcloud run services logs read dispatcher --region=$REGION --limit=50
```

# Cloud Run Job execution logs
```
gcloud run jobs executions list --region=$REGION
gcloud beta run jobs executions logs read [EXECUTION_ID] --region=$REGION
```

## Notes

- Dispatcher sets `PUBSUB_MSG` env var when launching jobs.
- Worker parses the filename to determine how long to sleep.
- `gcs-receiver` parses CloudEvent and publishes JSON to Pub/Sub.
- IAM bindings were required to allow `dispatcher` to call `runWithOverrides`.
- Environment variable `GOOGLE_CLOUD_PROJECT` must be explicitly set in `dispatcher`.
