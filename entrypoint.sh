#!/bin/bash
# StreamTeX container entrypoint — supports three serve modes:
#   dual           (default) Nginx + Streamlit — static fallback on error
#   static-only    Nginx only — no Streamlit, minimal resources
#   streamlit-only Streamlit only — legacy behaviour (no Nginx)
#
# Env vars:
#   STX_SERVE_MODE  dual | static-only | streamlit-only (default: dual)

set -e

MODE="${STX_SERVE_MODE:-dual}"

echo "[entrypoint] Mode: ${MODE}"

# --- Always: refresh cache and generate static HTML ---

# Clear stale caches
rm -rf .stx_cache .streamlit/cache

# Re-warm the page cache (for Streamlit fast first load)
if [ "$MODE" != "static-only" ]; then
    echo "[entrypoint] Warming up page cache..."
    uv run stx cache warmup . 2>/dev/null || true
fi

# Generate static HTML export — clean first to remove stale exports
rm -rf /app/static-html/*
echo "[entrypoint] Generating static HTML..."
uv run stx export html --output /app/static-html/ . 2>/dev/null || true

# Derive base_name (same as export CLI: basename of cwd)
BASE_NAME=$(basename "$(pwd)")
TARGET="${BASE_NAME}/${BASE_NAME}.html"
echo "[entrypoint] Static HTML: /html/ → ${TARGET}"
# Nginx snippet: 302 redirect from /html/ to the correct exported file
echo "return 302 /html/${TARGET};" > /app/static-html/.nginx-redirect.conf

# --- Start services based on mode ---

case "$MODE" in
    static-only)
        echo "[entrypoint] Starting Nginx (static-only)..."
        exec nginx -g "daemon off;"
        ;;
    streamlit-only)
        echo "[entrypoint] Starting Streamlit (no Nginx)..."
        exec uv run streamlit run book.py \
            --server.port=8501 --server.address=0.0.0.0
        ;;
    dual|*)
        echo "[entrypoint] Starting Nginx + Streamlit (dual mode)..."
        # Nginx in background, Streamlit as PID 1 (receives signals)
        nginx
        exec uv run streamlit run book.py \
            --server.port=8501 --server.address=0.0.0.0
        ;;
esac
