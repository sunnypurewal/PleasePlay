package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/golang-jwt/jwt/v5"
)

type AppleMusicResponse struct {
	Results struct {
		Songs struct {
			Data []struct {
				ID         string `json:"id"`
				Attributes struct {
					Name             string `json:"name"`
					ArtistName       string `json:"artistName"`
					AlbumName        string `json:"albumName"`
					DurationInMillis int    `json:"durationInMillis"`
					Artwork          struct {
						URL string `json:"url"`
					} `json:"artwork"`
					Previews []struct {
						URL string `json:"url"`
					} `json:"previews"`
				} `json:"attributes"`
			} `json:"data"`
		} `json:"songs"`
	} `json:"results"`
}

type Track struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	Artist     string `json:"artist"`
	Album      string `json:"album"`
	ArtworkURL string `json:"artwork_url"`
	Duration   int    `json:"duration"`
	PreviewURL string `json:"preview_url"`
}

func handler(request events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	priv_key := os.Getenv("APPLE_MUSIC_PRIVATE_KEY")
	KEY_ID := os.Getenv("APPLE_MUSIC_KEY_ID")
	TEAM_ID := os.Getenv("APPLE_MUSIC_TEAM_ID")

	if priv_key == "" || KEY_ID == "" || TEAM_ID == "" {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Missing Apple Music environment variables"}, nil
	}

	block, err := jwt.ParseECPrivateKeyFromPEM([]byte(priv_key))
	if err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Failed to parse private key: " + err.Error()}, nil
	}

	token := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{
		"iss": TEAM_ID,
		"iat": time.Now().Unix(),
		"exp": time.Now().Add(1 * time.Hour).Unix(),
	})

	token.Header["kid"] = KEY_ID

	tokenString, err := token.SignedString(block)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Failed to sign token: " + err.Error()}, nil
	}

	search_url := "https://api.music.apple.com/v1/catalog/us/search"
	
	// Extract the search term from the query string
	term := request.QueryStringParameters["term"]
	if term == "" {
		// Fallback or handle error - for now, we'll try to use the body if term is empty
		// but typically GET requests use query params
		term = request.Body
	}

	// Create the query parameters for Apple Music
	params := url.Values{}
	params.Add("term", term)
	// Adding typical types for music search to provide useful results
	params.Add("types", "songs")
	params.Add("limit", "5")

	reqURL := search_url + "?" + params.Encode()
    
	// Create request
	req, err := http.NewRequest("GET", reqURL, nil)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Failed to create request: " + err.Error()}, nil
	}

	req.Header.Add("Authorization", "Bearer "+tokenString)

	// Execute request
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Failed to execute request: " + err.Error()}, nil
	}
	defer resp.Body.Close()

	// Read response
	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Failed to read response: " + err.Error()}, nil
	}

	if resp.StatusCode != http.StatusOK {
		return events.APIGatewayV2HTTPResponse{StatusCode: resp.StatusCode, Body: string(bodyBytes)}, nil
	}

	var amResp AppleMusicResponse
	if err := json.Unmarshal(bodyBytes, &amResp); err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Failed to parse Apple Music response: " + err.Error()}, nil
	}

	var tracks []Track
	for _, song := range amResp.Results.Songs.Data {
		preview := ""
		if len(song.Attributes.Previews) > 0 {
			preview = song.Attributes.Previews[0].URL
		}

		tracks = append(tracks, Track{
			ID:         song.ID,
			Title:      song.Attributes.Name,
			Artist:     song.Attributes.ArtistName,
			Album:      song.Attributes.AlbumName,
			ArtworkURL: song.Attributes.Artwork.URL,
			Duration:   song.Attributes.DurationInMillis,
			PreviewURL: preview,
		})
	}

	respBody, err := json.Marshal(tracks)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: 500, Body: "Failed to marshal results: " + err.Error()}, nil
	}

	return events.APIGatewayV2HTTPResponse{
		StatusCode: 200,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(respBody),
	}, nil
}

func main() {
	lambda.Start(handler)
}
