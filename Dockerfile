# syntax=docker/dockerfile:1

FROM python:3.8-slim AS base

# Set environment variables for Python
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Builder stage: install dependencies in a venv
FROM base AS builder

# Install system dependencies required for pip packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        libjpeg-dev \
        zlib1g-dev \
        libfreetype6-dev \
        liblcms2-dev \
        libopenjp2-7 \
        libtiff5 \
        libwebp-dev \
        tcl8.6-dev \
        tk8.6-dev \
        python3-tk \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# Install pip dependencies using cache and bind mounts
# Install requirements in order: base.txt -> local.txt -> requirements.txt (which includes local.txt)
COPY --link requirements/ ./requirements/
COPY --link requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install -r requirements.txt

# Final stage: copy app code and venv, set up non-root user
FROM base AS final

# Create non-root user and group
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Copy virtual environment from builder
COPY --from=builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# Copy project source code (excluding .env and secrets)
COPY --link . .

# Set permissions for static and media directories
RUN mkdir -p /app/staticfiles /app/media && \
    chown -R appuser:appgroup /app/staticfiles /app/media

USER appuser

# Expose port 8000 (Django default)
EXPOSE 8000

# Collect static files at build time (optional, can also be done at runtime)
RUN python manage.py collectstatic --noinput

# Default command: run Django with Gunicorn if available, else fallback to runserver
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
# If you want to use Django's dev server instead, comment the above and uncomment below:
# CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
