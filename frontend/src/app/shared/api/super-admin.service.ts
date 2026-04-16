import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

// ── Interfaces (alineadas con los schemas del backend) ──────

export interface Servicio {
  id: number;
  nombre: string;
  descripcion: string | null;
}

export interface ServicioPayload {
  nombre: string;
  descripcion?: string | null;
}

export interface UsuarioPerfilOut {
  id: number;
  usuario_id: number;
  segundo_nombre: string | null;
  apellido_paterno: string;
  apellido_materno: string | null;
  foto_perfil: string | null;
  fecha_nacimiento: string | null;
}

export interface UsuarioOut {
  id: number;
  nombre: string;
  email: string;
  telefono: string | null;
  ci: string;
  fecha_creacion: string;
  perfil: UsuarioPerfilOut | null;
}

// ── Servicio HTTP ───────────────────────────────────────────

@Injectable({
  providedIn: 'root'
})
export class SuperAdminService {
  private http = inject(HttpClient);
  private readonly API = 'http://localhost:8000/api/v1/admin';

  // ── Servicios (Catálogo Maestro) ──────────────────────────

  getServicios(): Observable<Servicio[]> {
    return this.http.get<Servicio[]>(`${this.API}/servicios/`);
  }

  getServicio(id: number): Observable<Servicio> {
    return this.http.get<Servicio>(`${this.API}/servicios/${id}`);
  }

  crearServicio(payload: ServicioPayload): Observable<Servicio> {
    return this.http.post<Servicio>(`${this.API}/servicios/`, payload);
  }

  actualizarServicio(id: number, payload: Partial<ServicioPayload>): Observable<Servicio> {
    return this.http.patch<Servicio>(`${this.API}/servicios/${id}`, payload);
  }

  eliminarServicio(id: number): Observable<void> {
    return this.http.delete<void>(`${this.API}/servicios/${id}`);
  }

  // ── Usuarios (Listado / Baneo) ────────────────────────────

  getUsuarios(skip = 0, limit = 100): Observable<UsuarioOut[]> {
    return this.http.get<UsuarioOut[]>(`${this.API}/usuarios/`, {
      params: { skip: skip.toString(), limit: limit.toString() }
    });
  }

  getUsuario(id: number): Observable<UsuarioOut> {
    return this.http.get<UsuarioOut>(`${this.API}/usuarios/${id}`);
  }

  banearUsuario(id: number): Observable<UsuarioOut> {
    return this.http.patch<UsuarioOut>(`${this.API}/usuarios/${id}/ban`, {});
  }
}
