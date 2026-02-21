FROM python:3.11-slim

WORKDIR /app

# Prevent Python from buffering stdout/stderr
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install KServe SDK (uvicorn[standard] is pulled in automatically by kserve)
RUN pip install --no-cache-dir kserve==0.16.0

# Copy the transformer script
COPY services/kserve-transformer/iris-transformer.py .

# Expose the default KServe model server port
EXPOSE 8080

# Start the transformer; --predictor_host is injected by KServe at runtime
ENTRYPOINT ["python", "iris-transformer.py"]
