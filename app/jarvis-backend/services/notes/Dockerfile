FROM python:3.10-slim

# Set work directory
WORKDIR /service/app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy all files into container
COPY services/notes/. .

# Copy the utilities folder into a similar structure on the container
# Note the /, this is an absolute path
COPY utilities /utilities

# Install dependencies
RUN uv sync --no-cache --link-mode=copy

# Set the command to run the service
CMD ["uv", "run", "fastapi", "dev", "main.py", "--host", "0.0.0.0", "--port", "8000"]
