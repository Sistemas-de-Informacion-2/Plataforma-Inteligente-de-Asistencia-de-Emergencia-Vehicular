import { Routes } from '@angular/router';
import { LoginComponent } from './pages/login/login.component';
import { RegistroTallerComponent } from './pages/auth/registro-taller/registro-taller.component';
import { AdminLayoutComponent } from './widgets/layout/admin-layout/admin-layout.component';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { SucursalesComponent } from './pages/sucursales/sucursales.component';
import { TecnicosComponent } from './pages/tecnicos/tecnicos.component';
import { PerfilComponent } from './pages/perfil/perfil.component';
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
  
  // Rutas protegidas (Requieren autenticación) agrupadas bajo el Layout
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

  { 
    path: '**', 
    redirectTo: '/login' 
  }
];
