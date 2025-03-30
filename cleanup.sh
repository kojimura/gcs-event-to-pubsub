#!/bin/bash
set -euo pipefail

# Load environment variables
if [ -f .env ]; then
  source .env
else
  echo "Missing .env file. Please copy .env.template to .env and update values."
  exit 1
fi

# Delete Cloud Run Job
echo "Deleting Cloud Run Job..."
gcloud run jobs delete worker-job --region="$REGION" --quiet || true

# Delete Cloud Run Services
echo "Deleting Cloud Run services..."
gcloud run services delete dispatcher --region="$REGION" --quiet || true
gcloud run services delete gcs-receiver --region="$REGION" --quiet || true

# Delete Eventarc triggers
echo "Deleting Eventarc triggers..."
gcloud eventarc triggers delete gcs-to-pubsub-trigger --location="$REGION" --quiet || true
gcloud eventarc triggers delete pubsub-to-dispatcher --location="$REGION" --quiet || true

# Delete Pub/Sub topic
echo "Deleting Pub/Sub topic..."
gcloud pubsub topics delete "$TOPIC_NAME" --quiet || true

echo "Deleting image from Container Registry..."
gcloud container images delete gcr.io/$(gcloud config get-value project)/worker-job --quiet --force-delete-tags || true

echo "Cleanup complete."
