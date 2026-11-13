FROM python:3.12-alpine

LABEL org.opencontainers.image.title="careconnect-service" \
      org.opencontainers.image.source="https://github.com/<your-user>/careconnect-platform"

ARG APP_VERSION=dev
ENV SERVICE_NAME=careconnect-service \
    APP_VERSION=${APP_VERSION} \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN adduser -D -u 10001 appuser
USER 10001

EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

ENTRYPOINT ["python"]
CMD ["app.py"]
