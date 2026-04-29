# ── Stage 1: Build Angular ────────────────────────────────────
FROM node:22-alpine AS build

WORKDIR /app

# Copiar archivos de dependencias primero (cache de Docker)
COPY package.json package-lock.json ./

# Instalar dependencias
RUN npm ci --legacy-peer-deps

# Copiar el resto del código fuente
COPY . .

# Build de producción (usa fileReplacements → environment.prod.ts)
RUN npx ng build --configuration=production

# ── Stage 2: Servir con Nginx ─────────────────────────────────
FROM nginx:alpine

# Eliminar la config por defecto de Nginx
RUN rm -rf /usr/share/nginx/html/*

# Copiar los archivos estáticos del build de Angular
# Angular 17+ con @angular/build genera en dist/<nombre>/browser/
COPY --from=build /app/dist/frontend/browser /usr/share/nginx/html

# Copiar configuración de Nginx personalizada
COPY ../nginx/nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
