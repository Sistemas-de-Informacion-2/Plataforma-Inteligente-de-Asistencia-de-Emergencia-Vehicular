# 🚀 Guía de Despliegue — AWS EC2

## Pre-requisitos en tu instancia EC2

### 1. Lanzar instancia EC2
- **AMI**: Amazon Linux 2023 o Ubuntu 22.04
- **Tipo**: `t3.medium` (mínimo recomendado: 2 vCPU, 4GB RAM)
- **Security Group**: Abrir puertos:
  - **80** (HTTP) — desde `0.0.0.0/0`
  - **22** (SSH) — desde tu IP
- **Key Pair**: Descargar tu `.pem`

### 2. Conectarte por SSH
```bash
chmod 400 tu-llave.pem
ssh -i tu-llave.pem ec2-user@<IP-PUBLICA>   # Amazon Linux
# o
ssh -i tu-llave.pem ubuntu@<IP-PUBLICA>     # Ubuntu
```

### 3. Instalar Docker y Docker Compose

**Amazon Linux 2023:**
```bash
sudo yum update -y
sudo yum install -y docker git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Docker Compose plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Cerrar sesión y volver a conectar para aplicar el grupo docker
exit
```

**Ubuntu 22.04:**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-v2 git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
exit
```

---

## Despliegue

### 1. Clonar el repositorio
```bash
git clone <URL-DE-TU-REPO> emergencia
cd emergencia
```

### 2. Configurar variables de entorno
```bash
# Copiar la plantilla
cp .env.production .env

# Editar con tu IP pública de EC2
nano .env
```

**Cambios obligatorios en `.env`:**
```env
# Reemplazar con la IP pública de tu EC2
ALLOWED_ORIGINS=http://<IP-PUBLICA-EC2>
BACKEND_URL=http://backend:8000

# Generar una clave segura para JWT
SECRET_KEY=$(openssl rand -hex 32)

# Tu contraseña de BD (cambiar del default)
POSTGRES_PASSWORD=tu-password-seguro
DATABASE_URL=postgresql+asyncpg://admin:tu-password-seguro@db:5432/emergencia_vehicular
```

### 3. Construir y levantar
```bash
# Construir las imágenes (primera vez tarda ~5-10 min)
docker compose build

# Levantar en background
docker compose up -d
```

### 4. Verificar que todo funciona
```bash
# Ver estado de los contenedores
docker compose ps

# Ver logs del backend (debe mostrar "Migraciones completadas" y "Uvicorn running")
docker compose logs -f backend

# Ver logs de nginx
docker compose logs -f nginx

# Probar endpoints
curl http://localhost/health        # Nginx health
curl http://localhost/api/v1/       # Backend a través de Nginx (debería responder JSON)
curl http://localhost/              # Frontend Angular
```

### 5. Acceder desde el navegador
```
http://<IP-PUBLICA-EC2>/
```

---

## Comandos Útiles

```bash
# Ver logs en tiempo real
docker compose logs -f

# Reiniciar un servicio específico
docker compose restart backend

# Reconstruir solo un servicio
docker compose build backend
docker compose up -d backend

# Parar todo
docker compose down

# Parar y eliminar volúmenes (⚠️ BORRA LA BD)
docker compose down -v

# Ejecutar comandos dentro del backend
docker compose exec backend alembic upgrade head
docker compose exec backend python -c "print('hola')"

# Ver uso de recursos
docker stats
```

---

## Configuración para la App Flutter

En tu app Flutter, actualizar la URL base del API para que apunte a tu EC2:
```dart
// lib/core/config.dart o similar
static const String apiBaseUrl = 'http://<IP-PUBLICA-EC2>/api/v1';
static const String wsBaseUrl = 'ws://<IP-PUBLICA-EC2>/api/v1';
```

---

## Troubleshooting

| Problema | Solución |
|----------|----------|
| `502 Bad Gateway` | El backend aún no arrancó. Esperar 30s y verificar `docker compose logs backend` |
| `Connection refused` port 80 | Verificar Security Group de EC2 tiene puerto 80 abierto |
| `CORS error` en el browser | Verificar que `ALLOWED_ORIGINS` en `.env` incluye `http://<IP-PUBLICA>` |
| Migraciones fallan | Verificar `DATABASE_URL` en `.env`, que el password coincida con `POSTGRES_PASSWORD` |
| Frontend muestra página en blanco | Verificar `docker compose logs nginx` y que el build Angular fue exitoso |
| WebSocket no conecta | Verificar que la URL WS usa `ws://` (no `wss://`) ya que no tenemos SSL |
