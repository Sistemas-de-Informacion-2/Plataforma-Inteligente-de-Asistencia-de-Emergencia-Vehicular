// frontend/src/environments/environment.prod.ts
// Configuración para PRODUCCIÓN (Docker / AWS)
// URLs relativas: Nginx resuelve /api → backend y /uploads → backend
export const environment = {
  production: true,
  apiUrl: '/api/v1',
  backendUrl: '',
  wsUrl: `ws://${typeof window !== 'undefined' ? window.location.host : 'localhost'}/api/v1`,
};
