package main

import (
	"encoding/json"
	"net/http"
	"os"
	"time"
)

func main() {
	name := os.Getenv("SERVICE_NAME")
	if name == "" {
		name = "doctors"
	}
	host, _ := os.Hostname()

	reply := func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"service": name, "container": host})
	}
	http.HandleFunc("/", reply)
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"UP"}`))
	})
	http.HandleFunc("/work", func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(30 * time.Millisecond)
		reply(w, r)
	})
	// A Go program handles SIGTERM by exiting, even as PID 1, so no extra shutdown code is needed here.
	http.ListenAndServe(":8080", nil)
}
