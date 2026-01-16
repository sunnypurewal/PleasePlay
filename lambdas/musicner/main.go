package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

const (
	openaiAPIBase = "https://api.openai.com/v1"
	assistantID   = "asst_WBpwd1j6N1qN6WXUNVU2iCA5"
)

// Structs for OpenAI API
type Thread struct {
	ID string `json:"id"`
}

type MessageRequest struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type RunRequest struct {
	AssistantID string `json:"assistant_id"`
}

type Run struct {
	ID     string `json:"id"`
	Status string `json:"status"`
}

type Message struct {
	Role    string          `json:"role"`
	Content []MessageContent `json:"content"`
}

type MessageContent struct {
	Text *Text `json:"text,omitempty"`
}

type Text struct {
	Value string `json:"value"`
}

type MessageList struct {
	Data []Message `json:"data"`
}

// Struct for Lambda request body
type RequestBody struct {
	Query string `json:"query"`
}

func makeOpenAIRequest(method, url, apiKey string, requestBodyData, responseBody interface{}) error {
	var bodyReader io.Reader
	if requestBodyData != nil {
		jsonData, err := json.Marshal(requestBodyData)
		if err != nil {
			return fmt.Errorf("error marshalling request body: %w", err)
		}
		bodyReader = bytes.NewBuffer(jsonData)
	}

	req, err := http.NewRequest(method, url, bodyReader)
	if err != nil {
		return fmt.Errorf("error creating request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("OpenAI-Beta", "assistants=v2")


	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("error making request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("api request failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	if responseBody != nil {
		if err := json.NewDecoder(resp.Body).Decode(responseBody); err != nil {
			return fmt.Errorf("error decoding response body: %w", err)
		}
	}

	return nil
}

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: "OPENAI_API_KEY environment variable not set"}, nil
	}

	var reqBody RequestBody
	if err := json.Unmarshal([]byte(request.Body), &reqBody); err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 400, Body: "Invalid request body"}, nil
	}

	if reqBody.Query == "" {
		return events.APIGatewayProxyResponse{StatusCode: 400, Body: "Query not found in request body"}, nil
	}

	// 1. Create a Thread
	var thread Thread
	if err := makeOpenAIRequest("POST", openaiAPIBase+"/threads", apiKey, nil, &thread); err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: fmt.Sprintf("Error creating thread: %v", err)}, nil
	}

	// 2. Add a Message
	messageReq := MessageRequest{Role: "user", Content: reqBody.Query}
	// The API for adding a message does not return a body, so responseBody is nil
	if err := makeOpenAIRequest("POST", fmt.Sprintf("%s/threads/%s/messages", openaiAPIBase, thread.ID), apiKey, messageReq, nil); err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: fmt.Sprintf("Error creating message: %v", err)}, nil
	}

	// 3. Create a Run
	runReq := RunRequest{AssistantID: assistantID}
	var run Run
	if err := makeOpenAIRequest("POST", fmt.Sprintf("%s/threads/%s/runs", openaiAPIBase, thread.ID), apiKey, runReq, &run); err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: fmt.Sprintf("Error creating run: %v", err)}, nil
	}

	// 4. Wait for Run to complete
	for run.Status == "queued" || run.Status == "in_progress" {
		time.Sleep(1 * time.Second)
		if err := makeOpenAIRequest("GET", fmt.Sprintf("%s/threads/%s/runs/%s", openaiAPIBase, thread.ID, run.ID), apiKey, nil, &run); err != nil {
			return events.APIGatewayProxyResponse{StatusCode: 500, Body: fmt.Sprintf("Error retrieving run: %v", err)}, nil
		}
	}

	if run.Status != "completed" {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: fmt.Sprintf("Run finished with status: %s", run.Status)}, nil
	}

	// 5. Get Messages
	var messages MessageList
	if err := makeOpenAIRequest("GET", fmt.Sprintf("%s/threads/%s/messages", openaiAPIBase, thread.ID), apiKey, nil, &messages); err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: fmt.Sprintf("Error listing messages: %v", err)}, nil
	}

	// Find the assistant's response
	var assistantResponse string
	// Messages are returned in descending order. We want the first one from the assistant.
	for _, msg := range messages.Data {
		if msg.Role == "assistant" && len(msg.Content) > 0 && msg.Content[0].Text != nil {
			assistantResponse = msg.Content[0].Text.Value
			break
		}
	}

	return events.APIGatewayProxyResponse{StatusCode: 200, Body: assistantResponse}, nil
}

func main() {
	lambda.Start(handler)
}
