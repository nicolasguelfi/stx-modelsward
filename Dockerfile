FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 \
    STREAMLIT_SERVER_HEADLESS=true STREAMLIT_BROWSER_GATHERUSAGESTATS=false \
    UV_LINK_MODE=copy
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev
COPY . .
EXPOSE 8501
HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health
ENTRYPOINT ["uv", "run", "streamlit", "run", "book.py", \
            "--server.port=8501", "--server.address=0.0.0.0"]
