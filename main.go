package main

import (
	"net/http"

	"github.com/labstack/echo"
)

func main() {
	e := echo.New()
	e.GET("/ping", ping)
	e.GET("/movies", movies)
	e.Start(":8000")
}

func ping(c echo.Context) error {
	return c.String(http.StatusOK, "OK")
}

func movies(c echo.Context) error {
	rating := c.QueryParam("rating")
	if rating == "" {
		rating = "70"
	}

	client := &http.Client{}
	req, _ := http.NewRequest("GET", "http://localhost:1080/movies", nil)
	req.Header.Add("Accept", `application/json`)
	q := req.URL.Query()
	q.Add("rating", rating)
	req.URL.RawQuery = q.Encode()
	if resp, err := client.Do(req); err != nil {
		panic(err)
	} else {
		return c.Stream(http.StatusOK, "application/json", resp.Body)
	}
}
