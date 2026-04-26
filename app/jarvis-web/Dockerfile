# Multi-stage Dockerfile for jarvis-web.
# - builder: install pinned wheels into /install
# - runtime: slim image, non-root user, copy in deps + app
#
# The same Dockerfile is used to build every version (v1/v2/v3) of jarvis-web.
# Behavior between versions is controlled entirely by env vars at deploy time.

FROM python:3.12-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/install/bin:${PATH}" \
    PYTHONPATH="/install/lib/python3.12/site-packages"

# Drop privileges; the runtime user owns nothing we don't explicitly chown.
RUN groupadd --system app && useradd --system --gid app --home /app app

COPY --from=builder /install /install
WORKDIR /app
COPY --chown=app:app app /app/app

USER app
EXPOSE 8080

# Healthcheck doubles as a sanity check during local `docker run` testing.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; \
    sys.exit(0 if urllib.request.urlopen('http://localhost:8080/readyz').status==200 else 1)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
