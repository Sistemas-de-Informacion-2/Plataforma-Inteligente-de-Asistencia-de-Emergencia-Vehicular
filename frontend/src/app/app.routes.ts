import { Routes } from '@angular/router';
import { LoginComponent } from './pages/login/login.component';
import { AdminLayoutComponent } from './widgets/layout/admin-layout/admin-layout.component';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { authGuard } from './core/guards/auth.guard';

export const routes: Routes = [
  // Rutas públicas
  { 
    path: 'login', 
    component: LoginComponent 
  },
  
  // Rutas protegidas (Requieren autenticación)
  { 
    path: 'dashboard', 
    component: AdminLayoutComponent,
    canActivate: [authGuard],
    children: [
      { path: '', component: DashboardComponent },
      // Estructura lista para futuras páginas como:
      // { path: 'solicitudes', component: SolicitudesComponent }
    ]
  },

  // Redirecciones
  { 
    path: '', 
    redirectTo: '/dashboard', 
    pathMatch: 'full' 
  },
  { 
    path: '**', 
    redirectTo: '/dashboard' 
  }
];
