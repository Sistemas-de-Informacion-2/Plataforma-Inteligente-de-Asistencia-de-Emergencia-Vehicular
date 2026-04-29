// src/app/core/guards/auth.guard.ts
import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../../shared/api/auth.service';

export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  // Leer el signal del servicio
  if (authService.isAuthenticated()) {
    return true;
  }

  // Redirigir al login preservando a donde quería ir (en un caso más avanzado puedes usar queryParams)
  router.navigate(['/login']);
  return false;
};
