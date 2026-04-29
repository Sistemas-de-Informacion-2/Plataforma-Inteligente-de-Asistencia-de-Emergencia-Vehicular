#!/bin/bash
# backend/entrypoint.sh
# Script de inicio del contenedor backend.
# 1. Espera a que PostgreSQL esté listo
# 2. Ejecuta las migraciones de Alembic
# 3. Inicia Uvicorn
set -e

echo "⏳ Esperando a que PostgreSQL esté disponible..."

# Esperar hasta que PostgreSQL acepte conexiones (máximo 30 segundos)
MAX_RETRIES=30
RETRY_COUNT=0

while ! python -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    s.connect(('db', 5432))
    s.close()
    exit(0)
except:
    exit(1)
" 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "❌ No se pudo conectar a PostgreSQL después de ${MAX_RETRIES} intentos"
        exit 1
    fi
    echo "   Intento $RETRY_COUNT/$MAX_RETRIES — PostgreSQL no está listo, reintentando en 1s..."
    sleep 1
done

echo "✅ PostgreSQL está listo!"

# ── Ejecutar migraciones ──────────────────────────────────────
echo "🔄 Ejecutando migraciones de Alembic..."
alembic upgrade head
echo "✅ Migraciones completadas!"

# ── Iniciar Uvicorn ───────────────────────────────────────────
echo "🚀 Iniciando el servidor FastAPI..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2
