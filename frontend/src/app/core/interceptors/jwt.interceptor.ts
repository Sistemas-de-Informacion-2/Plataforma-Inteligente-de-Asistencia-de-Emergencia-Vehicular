// src/app/core/interceptors/jwt.interceptor.ts
import { HttpInterceptorFn } from '@angular/common/http';

export const jwtInterceptor: HttpInterceptorFn = (req, next) => {
  // Los interceptores y guards corren en SSR también, por lo que verificamos que localStorage exista
  const token = typeof localStorage !== 'undefined' ? localStorage.getItem('access_token') : null;

  if (token) {
    // Clonamos la petición inmutablemente
    const clonedReq = req.clone({
      setHeaders: {
        Authorization: `Bearer ${token}`
      }
    });

    return next(clonedReq);
  }

  // Si no hay token, dejamos pasar la petición inalterada
  return next(req);
};
