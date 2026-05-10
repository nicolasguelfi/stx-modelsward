FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 \
    STREAMLIT_SERVER_HEADLESS=true STREAMLIT_BROWSER_GATHERUSAGESTATS=false \
    UV_LINK_MODE=copy

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl nginx-light \
    && rm -rf /var/lib/apt/lists/*

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

# Cache-bust: changing SOURCE_COMMIT invalidates layers so uv sync
# fetches the latest PyPI packages.
ARG SOURCE_COMMIT=unknown

# Install dependencies
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev && \
    uv pip install rich jinja2

# Copy project files
COPY . .

# Nginx configuration for dual-mode (Streamlit + static HTML)
COPY nginx.conf /etc/nginx/nginx.conf

# Entrypoint script (supports dual / static-only / streamlit-only modes)
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Pre-generate static HTML + default nginx redirect snippet.
# The entrypoint will clean and regenerate at runtime.
RUN mkdir -p /app/static-html && \
    echo 'return 302 /html/;' > /app/static-html/.nginx-redirect.conf && \
    (uv run stx export html --output /app/static-html/ . || true)

# STX_SERVE_MODE controls which services start (set at runtime)
#   dual           = Nginx (:80) + Streamlit (:8501) — default
#   static-only    = Nginx (:80) only
#   streamlit-only = Streamlit (:8501) only — legacy behaviour
ENV STX_SERVE_MODE="dual"

EXPOSE 80 8501

# Health check: Streamlit first, then Nginx static
HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health 2>/dev/null \
    || curl -fsL http://localhost:80/html/ -o /dev/null

ENTRYPOINT ["/app/entrypoint.sh"]
