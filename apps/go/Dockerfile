FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY main.go ./
RUN go mod download && go mod tidy
RUN go build -o inventory-service main.go

FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/inventory-service .

EXPOSE 8080

CMD ["./inventory-service"]
