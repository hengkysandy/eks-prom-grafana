package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
)

type Item struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	Quantity  int    `json:"quantity"`
	Available bool   `json:"available"`
	Location  string `json:"location"`
}

type LogEntry struct {
	Timestamp  string `json:"timestamp"`
	Level      string `json:"level"`
	Message    string `json:"message"`
	Service    string `json:"service"`
	Method     string `json:"method,omitempty"`
	Path       string `json:"path,omitempty"`
	StatusCode int    `json:"status_code,omitempty"`
}

var inventory = []Item{
	{ID: 1, Name: "Laptop", Quantity: 10, Available: true, Location: "Warehouse A"},
	{ID: 2, Name: "Mouse", Quantity: 50, Available: true, Location: "Warehouse B"},
	{ID: 3, Name: "Keyboard", Quantity: 30, Available: true, Location: "Warehouse A"},
}

var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)
	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "http_request_duration_seconds",
			Help: "HTTP request duration in seconds",
		},
		[]string{"method", "endpoint"},
	)
	httpErrorsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_errors_total",
			Help: "Total number of HTTP errors",
		},
		[]string{"method", "endpoint", "status", "error_type"},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(httpErrorsTotal)
}

func logJSON(level, message string, method, path string, statusCode int) {
	entry := LogEntry{
		Timestamp:  time.Now().UTC().Format(time.RFC3339),
		Level:      level,
		Message:    message,
		Service:    "go-inventory",
		Method:     method,
		Path:       path,
		StatusCode: statusCode,
	}
	jsonData, _ := json.Marshal(entry)
	fmt.Fprintln(os.Stdout, string(jsonData))
}

func initTracer() func(context.Context) error {
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "tempo.monitoring.svc.cluster.local:4318"
	} else {
		// Remove http:// prefix and /v1/traces suffix if present
		endpoint = strings.TrimPrefix(endpoint, "http://")
		endpoint = strings.TrimPrefix(endpoint, "https://")
		endpoint = strings.TrimSuffix(endpoint, "/v1/traces")
	}

	exporter, err := otlptracehttp.New(context.Background(),
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		log.Fatalf("Failed to create OTLP exporter: %v", err)
	}

	res, err := resource.New(context.Background(),
		resource.WithAttributes(semconv.ServiceName("go-inventory")),
	)
	if err != nil {
		log.Fatalf("Failed to create resource: %v", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)

	return tp.Shutdown
}

func metricsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Create a response writer wrapper to capture status code
		rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		
		next(rw, r)
		
		duration := time.Since(start).Seconds()
		statusStr := strconv.Itoa(rw.statusCode)
		
		httpRequestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
		httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, statusStr).Inc()
		
		logJSON("info", "HTTP Request", r.Method, r.URL.Path, rw.statusCode)
		
		if rw.statusCode >= 400 {
			httpErrorsTotal.WithLabelValues(r.Method, r.URL.Path, statusStr, "http_error").Inc()
		}
	}
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "go-inventory",
	})
}

func inventoryHandler(w http.ResponseWriter, r *http.Request) {
	logJSON("info", fmt.Sprintf("Fetching all inventory, count: %d", len(inventory)), r.Method, r.URL.Path, 200)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"inventory": inventory,
		"count":     len(inventory),
	})
}

func inventoryItemHandler(w http.ResponseWriter, r *http.Request) {
	// Extract ID from path /inventory/{id}
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 3 {
		logJSON("warn", "Invalid inventory request", r.Method, r.URL.Path, 400)
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	
	idStr := pathParts[2]
	id, err := strconv.Atoi(idStr)
	if err != nil {
		logJSON("warn", "Invalid ID format", r.Method, r.URL.Path, 400)
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

	for _, item := range inventory {
		if item.ID == id {
			logJSON("info", fmt.Sprintf("Inventory item fetched: %d", id), r.Method, r.URL.Path, 200)
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(item)
			return
		}
	}
	
	logJSON("warn", fmt.Sprintf("Inventory item not found: %d", id), r.Method, r.URL.Path, 404)
	http.Error(w, "Item not found", http.StatusNotFound)
}

// Error test endpoints
func error500Handler(w http.ResponseWriter, r *http.Request) {
	logJSON("error", "Simulated 500 error", r.Method, r.URL.Path, 500)
	httpErrorsTotal.WithLabelValues(r.Method, r.URL.Path, "500", "internal_server_error").Inc()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusInternalServerError)
	json.NewEncoder(w).Encode(map[string]string{
		"error":   "Internal Server Error",
		"message": "Simulated error",
	})
}

func errorDBHandler(w http.ResponseWriter, r *http.Request) {
	logJSON("error", "Simulated database error", r.Method, r.URL.Path, 503)
	httpErrorsTotal.WithLabelValues(r.Method, r.URL.Path, "503", "database_error").Inc()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusServiceUnavailable)
	json.NewEncoder(w).Encode(map[string]string{
		"error":   "Service Unavailable",
		"message": "Database connection failed",
	})
}

func errorTimeoutHandler(w http.ResponseWriter, r *http.Request) {
	logJSON("warn", "Simulated timeout", r.Method, r.URL.Path, 504)
	time.Sleep(5 * time.Second)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusGatewayTimeout)
	json.NewEncoder(w).Encode(map[string]string{
		"error":   "Gateway Timeout",
		"message": "Request took too long",
	})
}

func main() {
	shutdown := initTracer()
	defer shutdown(context.Background())

	http.Handle("/health", otelhttp.NewHandler(http.HandlerFunc(metricsMiddleware(healthHandler)), "health"))
	http.Handle("/inventory", otelhttp.NewHandler(http.HandlerFunc(metricsMiddleware(inventoryHandler)), "inventory"))
	http.Handle("/inventory/", otelhttp.NewHandler(http.HandlerFunc(metricsMiddleware(inventoryItemHandler)), "inventory-item"))
	http.Handle("/error/500", otelhttp.NewHandler(http.HandlerFunc(metricsMiddleware(error500Handler)), "error-500"))
	http.Handle("/error/db", otelhttp.NewHandler(http.HandlerFunc(metricsMiddleware(errorDBHandler)), "error-db"))
	http.Handle("/error/timeout", otelhttp.NewHandler(http.HandlerFunc(metricsMiddleware(errorTimeoutHandler)), "error-timeout"))
	http.Handle("/metrics", promhttp.Handler())

	port := "8080"
	logJSON("info", fmt.Sprintf("Starting Go Inventory Service on port %s", port), "", "", 0)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
