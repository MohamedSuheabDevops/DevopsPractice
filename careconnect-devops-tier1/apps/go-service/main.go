package main

import (
	"encoding/json"
	"net/http"
	"os"
)

func main() {
	name := os.Getenv("SERVICE_NAME")
	if name == "" {
		name = "catalog-service-go"
	}
	host, _ := os.Hostname()

	reply := func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"service": name, "container": host, "path": r.URL.Path,
		})
	}
	http.HandleFunc("/", reply)
	http.HandleFunc("/health", reply)
	http.ListenAndServe(":8000", nil)
}
