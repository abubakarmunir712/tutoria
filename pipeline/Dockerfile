FROM python:3.12-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download the local embedding model into the image at a fixed path, so the
# container never needs network access to Hugging Face at runtime (no cold-start
# delay or flakiness on the first real request).
ENV FASTEMBED_CACHE_DIR=/app/model_cache
RUN python -c "from fastembed import TextEmbedding; TextEmbedding(model_name='BAAI/bge-small-en-v1.5', cache_dir='/app/model_cache')"

COPY src ./src
COPY data/structured/images ./data/structured/images

EXPOSE 8000
WORKDIR /app/src
CMD ["uvicorn", "service:app", "--host", "0.0.0.0", "--port", "8000"]
