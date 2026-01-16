# Makefile for deploying the musicner Go Lambda function.
#
# Common commands:
#  - `make all`: Build and zip the project (default).
#  - `make update`: Redeploy the function code to AWS. This is the most common command.
#  - `make create`: Create the function on AWS for the first time.
#  - `make clean`: Remove build files.
#
# Before running `make create`:
# 1. Make sure you have the AWS CLI installed and configured.
# 2. Set the `ROLE_ARN` variable below to your Lambda execution role ARN.
#    To find your role ARN, you can use the AWS Console (IAM -> Roles) or run the following CLI command,
#    replacing `YourLambdaRoleName` with the actual name of your IAM role:
#
#    aws iam get-role --role-name YourLambdaRoleName --query Role.Arn --output text

.PHONY: all build zip update create clean

# --- Configuration ---
FUNCTION_NAME := music-search
# Replace this with the ARN of your IAM role for Lambda execution.
ROLE_ARN      := "arn:aws:iam::227530433709:role/musicner-lambda-role"
# ---

BINARY_NAME   := bootstrap
ZIP_FILE      := function.zip


# Default payload for invocation
PAYLOAD       := '{"body": "The Beatles"}'

all: build zip

# Build the Go binary for the Lambda environment (linux/arm64)
build:
	@echo "Building Go binary..."
	GOOS=linux GOARCH=arm64 go build -o $(BINARY_NAME) main.go

# Package the binary into a zip file for deployment
# The -j flag flattens the zip archive, removing any directory structure.
zip:
	@echo "Zipping binary..."
	zip -j $(ZIP_FILE) $(BINARY_NAME)

# Update the code for an existing Lambda function
update: build zip
	@echo "Updating Lambda function code on AWS..."
	aws lambda update-function-code \
		--function-name $(FUNCTION_NAME) \
		--zip-file fileb://$(ZIP_FILE)

# Create a new Lambda function
create: build zip
	@echo "Creating new Lambda function on AWS..."
	aws lambda create-function \
		--function-name $(FUNCTION_NAME) \
		--runtime provided.al2 \
		--handler bootstrap \
		--architectures arm64 \
		--role $(ROLE_ARN) \
		--zip-file fileb://$(ZIP_FILE)

# Invoke the Lambda function
invoke:
	@echo "Invoking Lambda function..."
	aws lambda invoke \
		--function-name $(FUNCTION_NAME) \
		--payload $(PAYLOAD) \
		--cli-binary-format raw-in-base64-out \
		response.json
	@echo "Response:"
	@cat response.json
	@echo ""

# Clean up build artifacts
clean:
	@echo "Cleaning up..."
	rm -f $(BINARY_NAME) $(ZIP_FILE) response.json
