# Backend Dockerfile for COBOL Bug Analyzer
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose Flask port (Cloud Run uses PORT env var, local uses 5000)
EXPOSE 5000
EXPOSE 8080

# Set environment variables
ENV FLASK_APP=app.py
ENV FLASK_ENV=production
ENV PYTHONUNBUFFERED=1
ENV PORT=5000

# Run Flask application with gunicorn for production
# Cloud Run sets PORT=8080, local development uses PORT=5000
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 app:app
