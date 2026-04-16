import { Routes } from '@angular/router';
import { LoginComponent } from './pages/login/login.component';
import { RegistroTallerComponent } from './pages/auth/registro-taller/registro-taller.component';
import { AdminLayoutComponent } from './widgets/layout/admin-layout/admin-layout.component';
import { SuperAdminLayoutComponent } from './widgets/layout/super-admin-layout/super-admin-layout.component';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { SucursalesComponent } from './pages/sucursales/sucursales.component';
import { TecnicosComponent } from './pages/tecnicos/tecnicos.component';
import { PerfilComponent } from './pages/perfil/perfil.component';
import { SaServiciosComponent } from './pages/super-admin/sa-servicios/sa-servicios.component';
import { SaUsuariosComponent } from './pages/super-admin/sa-usuarios/sa-usuarios.component';
import { authGuard } from './core/guards/auth.guard';

export const routes: Routes = [
  // Rutas públicas
  { 
    path: 'login', 
    component: LoginComponent 
  },
  {
    path: 'registro-taller',
    component: RegistroTallerComponent
  },
  
  // Rutas protegidas — Admin de Taller (ADMIN_TALLER)
  { 
    path: '', 
    component: AdminLayoutComponent,
    canActivate: [authGuard],
    children: [
      { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
      { path: 'dashboard', component: DashboardComponent },
      { path: 'sucursales', component: SucursalesComponent },
      { path: 'tecnicos', component: TecnicosComponent },
      { path: 'perfil', component: PerfilComponent }
    ]
  },

  // Rutas protegidas — Super Admin (SUPER_ADMIN / Plataforma)
  {
    path: 'super-admin',
    component: SuperAdminLayoutComponent,
    canActivate: [authGuard],
    children: [
      { path: '', redirectTo: 'servicios', pathMatch: 'full' },
      { path: 'servicios', component: SaServiciosComponent },
      { path: 'usuarios', component: SaUsuariosComponent }
    ]
  },

  { 
    path: '**', 
    redirectTo: '/login' 
  }
];

