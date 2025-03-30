#!/bin/bash
set -euo pipefail

# Load environment variables
if [ -f .env ]; then
  source .env
else
  echo "Missing .env file. Please copy .env.template to .env and update values."
  exit 1
fi

# Create Pub/Sub topic
echo "Creating Pub/Sub topic..."
gcloud pubsub topics create "$TOPIC_NAME" || echo "Topic already exists"

# Deploy gcs-receiver
cd receiver

echo "Deploying gcs-receiver..."
gcloud run deploy gcs-receiver \
  --source . \
  --region="$REGION" \
  --memory=512Mi \
  --set-env-vars TOPIC_NAME="$TOPIC_NAME",GCP_PROJECT="$(gcloud config get-value project)" \
  --no-allow-unauthenticated

cd ../dispatcher

echo "Deploying dispatcher..."
gcloud run deploy dispatcher \
  --source . \
  --region="$REGION" \
  --memory=512Mi \
  --set-env-vars JOB_NAME=worker-job,JOB_REGION="$REGION",GOOGLE_CLOUD_PROJECT="$(gcloud config get-value project)" \
  --no-allow-unauthenticated

cd ../worker-job
echo "Building Job container image ..."
gcloud builds submit --tag gcr.io/$(gcloud config get-value project)/worker-job

echo "Creating Cloud Run Job worker-job..."
gcloud run jobs create worker-job \
  --image gcr.io/$(gcloud config get-value project)/worker-job \
  --region="$REGION" \
  --memory=512Mi \
  --task-timeout 3600s

cd ..

# Create Eventarc triggers
echo "Creating Eventarc triggers..."
gcloud eventarc triggers create gcs-to-pubsub-trigger \
  --location="$REGION" \
  --destination-run-service=gcs-receiver \
  --destination-run-region="$REGION" \
  --event-filters="type=google.cloud.storage.object.v1.finalized" \
  --event-filters="bucket=$BUCKET_NAME" \
  --service-account="$(gcloud projects describe $(gcloud config get-value project) --format='value(projectNumber)')-compute@developer.gserviceaccount.com" || true

gcloud eventarc triggers create pubsub-to-dispatcher \
  --location="$REGION" \
  --destination-run-service=dispatcher \
  --destination-run-region="$REGION" \
  --transport-topic="$TOPIC_NAME" \
  --event-filters="type=google.cloud.pubsub.topic.v1.messagePublished" \
  --service-account="$(gcloud projects describe $(gcloud config get-value project) --format='value(projectNumber)')-compute@developer.gserviceaccount.com" || true

echo "Deployment complete."
