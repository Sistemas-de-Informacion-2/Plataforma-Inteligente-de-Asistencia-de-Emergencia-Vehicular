# ── Stage 1: Build Angular ────────────────────────────────────
FROM node:22-alpine AS build

WORKDIR /app

# Copiar archivos de dependencias primero (cache de Docker)
COPY frontend/package.json frontend/package-lock.json ./

# Instalar dependencias
RUN npm ci --legacy-peer-deps

# Copiar el resto del código fuente del frontend
COPY frontend/ .

# Build de producción (usa fileReplacements → environment.prod.ts)
RUN npx ng build --configuration=production

# ── Stage 2: Nginx ────────────────────────────────────────────
FROM nginx:alpine

# Eliminar la config por defecto
RUN rm -rf /usr/share/nginx/html/* /etc/nginx/conf.d/default.conf

# Copiar archivos estáticos del build Angular
COPY --from=build /app/dist/frontend/browser /usr/share/nginx/html

# Copiar configuración personalizada de Nginx
COPY nginx/nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
