package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "hello from a verified build")
	})
	fmt.Println("listening on :8080")
	_ = http.ListenAndServe(":8080", nil)
}
