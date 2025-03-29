# Makefile for GCP Cloud Run Job project

ENV_FILE := .env

include $(ENV_FILE)

.PHONY: deploy cleanup logs

deploy:
	./deploy.sh

cleanup:
	./cleanup.sh

logs:
	gcloud run jobs executions list --region=$(REGION)
