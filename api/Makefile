# Makefile for managing AWS HTTP API (v2) for the PleasePlay API

# --- Configuration ---
API_NAME      := PleasePlayAPI
REGION        := us-east-1
LAMBDA_NAME   := music-search
# ---------------------

.PHONY: help create-api setup-integration setup-route setup-stages add-permission full-setup clean delete-api deploy test

help:
	@echo "Available commands:"
	@echo "  make create-api        - Create a new HTTP API"
	@echo "  make setup-stages      - Create staging and production stages"
	@echo "  make full-setup        - Run the entire setup process"
	@echo "  make deploy           - Show the deployment URLs"
	@echo "  make test             - Test the staging endpoint"
	@echo "  make delete-api        - Delete the API Gateway"

setup: full-setup

# Dynamic lookups for IDs
# Note: apigatewayv2 uses different commands than apigateway
# API_ID ?= $(shell aws apigatewayv2 get-apis --query "Items[?Name=='$(API_NAME)'].ApiId" --output text)
API_ID := w4w5iv0ad5
ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
LAMBDA_ARN := arn:aws:lambda:$(REGION):$(ACCOUNT_ID):function:$(LAMBDA_NAME)

create-api:
	@echo "Creating HTTP API: $(API_NAME)..."
	aws apigatewayv2 create-api \
		--name $(API_NAME) \
		--protocol-type HTTP \
		--region $(REGION)

setup-integration:
	@echo "Creating Lambda integration for $(LAMBDA_NAME)..."
	$(eval INT_ID := $(shell aws apigatewayv2 create-integration \
		--api-id $(API_ID) \
		--integration-type AWS_PROXY \
		--integration-uri $(LAMBDA_ARN) \
		--payload-format-version 2.0 \
		--query IntegrationId --output text))
	@echo "Integration created with ID: $(INT_ID)"

setup-route:
	@echo "Creating route GET /search..."
	$(eval INT_ID := $(shell aws apigatewayv2 get-integrations --api-id $(API_ID) --query "Items[0].IntegrationId" --output text))
	aws apigatewayv2 create-route \
		--api-id $(API_ID) \
		--route-key "GET /search" \
		--target integrations/$(INT_ID)

setup-stages:
	@echo "Creating staging stage..."
	aws apigatewayv2 create-stage \
		--api-id $(API_ID) \
		--stage-name staging \
		--auto-deploy
	@echo "Creating production stage..."
	aws apigatewayv2 create-stage \
		--api-id $(API_ID) \
		--stage-name production \
		--auto-deploy

add-permission:
	@echo "Adding Lambda permission for HTTP API..."
	aws lambda add-permission \
		--function-name $(LAMBDA_NAME) \
		--statement-id apigateway-http-access \
		--action lambda:InvokeFunction \
		--principal apigateway.amazonaws.com \
		--source-arn "arn:aws:execute-api:$(REGION):$(ACCOUNT_ID):$(API_ID)/*"

full-setup:
	$(MAKE) create-api
	@echo "Waiting for API to be available..."
	@sleep 3
	$(MAKE) setup-integration
	$(MAKE) setup-route
	$(MAKE) setup-stages
	$(MAKE) add-permission
	@echo "\033[32mHTTP API created successfully!\033[0m"
	@echo "\033[32mStaging: https://$(API_ID).execute-api.$(REGION).amazonaws.com/staging/search\033[0m"
	@echo "\033[32mProduction: https://$(API_ID).execute-api.$(REGION).amazonaws.com/production/search\033[0m"

deploy:
	@echo "API Gateawy is auto-deploy enabled."
	@echo "Staging: https://$(API_ID).execute-api.$(REGION).amazonaws.com/staging/search"
	@echo "Production: https://$(API_ID).execute-api.$(REGION).amazonaws.com/production/search"

test:
	curl "https://$(API_ID).execute-api.$(REGION).amazonaws.com/staging/search?term=Metallica"

delete-api:
	@echo "Deleting HTTP API: $(API_ID)..."
	aws apigatewayv2 delete-api --api-id $(API_ID)
