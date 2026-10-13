#!/usr/bin/env bash
set -eo pipefail

cd "$(dirname "$0")"

echo "========================================="
echo "       Procura Procurement Sandbox       "
echo "========================================="
echo ""

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "❌ Error: Node.js 18+ and npm are required."
  exit 1
fi

if [[ ! -d node_modules ]]; then
  echo "📦 Installing Node.js dependencies..."
  npm install
fi

# Load .env if present
if [[ -f .env ]]; then
  echo "⚙️  Loading configuration from .env..."
  set -a
  source .env
  set +a
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  export DATABASE_URL="postgres://postgres:postgres@localhost:5432/procura"
  if [[ ! -f .env ]]; then
    echo "DATABASE_URL=$DATABASE_URL" > .env
    echo "PORT=3000" >> .env
    echo "✅ Created default .env file."
  fi
fi

echo "🗄️  Applying PostgreSQL schema and seed data..."
if ! node db/setup.js; then
  echo ""
  echo "⚠️  Database setup could not connect to PostgreSQL ($DATABASE_URL)."
  echo "Starting the web server anyway so you can view the application interface..."
  echo ""
fi

PORT="${PORT:-3000}"
echo "🚀 Starting Procura at http://localhost:$PORT"
echo "   Press Ctrl+C to stop the server."
npm run dev
