# Multi-stage build for chaos-broker handler service
# Build context should be the project root directory
FROM python:3.9-slim as builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

# Copy local packages first (from project root context)
COPY Experiment-Broker-Module/experiment_code/experiment_bofa /build/experiment_bofa
COPY chaos-toolkit-lite/experiment_runner_lite /build/experiment_runner_lite
COPY Experiment-Broker-Logging-Module /build/Experiment-Broker-Logging-Module

# Copy handler and requirements
COPY Experiment-Broker-Module/experiment_code/lambda/requirements.txt /build/requirements.txt
COPY Experiment-Broker-Module/experiment_code/lambda/handler.py /build/handler.py

# Install Python dependencies
# Note: Installing packages normally (not editable) for multi-stage build compatibility
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir /build/experiment_bofa && \
    pip install --no-cache-dir /build/experiment_runner_lite && \
    pip install --no-cache-dir /build/Experiment-Broker-Logging-Module

# Final stage
FROM python:3.9-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy handler and service wrapper (from project root context)
COPY Experiment-Broker-Module/experiment_code/lambda/handler.py /app/handler.py
COPY terraform/openshift_deployment/orchestrator/handler_service.py /app/handler_service.py
COPY terraform/openshift_deployment/orchestrator/orchestrator.py /app/orchestrator.py

# Create directories for experiments and journals
RUN mkdir -p /app/experiments /app/journals /app/local_only/experiments /app/local_only/journals

# Set environment variables
ENV PYTHONPATH=/app
ENV local_mode=openshift

# Expose HTTP port for handler service
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the handler HTTP service
CMD ["python", "/app/handler_service.py"]

