# ---------- Stage 1: compile ----------
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download                           # cached unless go.mod changes
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/doctors .

# ---------- Stage 2: tiny runtime ----------
FROM alpine:3.20
LABEL org.opencontainers.image.title="careconnect-doctors"
RUN adduser -D -u 10001 app
COPY --from=build /out/doctors /usr/local/bin/doctors
USER 10001
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1
ENTRYPOINT ["/usr/local/bin/doctors"]
