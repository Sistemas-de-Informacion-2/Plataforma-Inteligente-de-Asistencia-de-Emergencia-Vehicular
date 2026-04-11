import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

export interface UsuarioPerfil {
  segundo_nombre: string | null;
  apellido_paterno: string | null;
  apellido_materno: string | null;
  foto_perfil: string | null;
  fecha_nacimiento: string | null;
}

export interface UsuarioData {
  id: number;
  nombre: string;
  email: string;
  telefono: string | null;
  ci: string;
  fecha_creacion: string;
  perfil: UsuarioPerfil | null;
}

export interface UsuarioPerfilUpdatePayload {
  nombre?: string;
  telefono?: string;
  segundo_nombre?: string | null;
  apellido_paterno?: string | null;
  apellido_materno?: string | null;
  foto_perfil?: string | null;
  fecha_nacimiento?: string | null;
}

@Injectable({
  providedIn: 'root'
})
export class UsuarioService {
  private http = inject(HttpClient);
  private readonly API_URL = 'http://localhost:8000/api/v1/usuarios';

  // Usamos signals para almacenar la sesión actual o perfil actual del usaurio
  public currentUser = signal<UsuarioData | null>(null);

  getMe(): Observable<UsuarioData> {
    return this.http.get<UsuarioData>(`${this.API_URL}/me`).pipe(
      tap(data => {
        this.currentUser.set(data);
      })
    );
  }

  updateMyProfile(payload: UsuarioPerfilUpdatePayload): Observable<UsuarioData> {
    return this.http.patch<UsuarioData>(`${this.API_URL}/me/perfil`, payload).pipe(
      tap(data => {
        // Actualizamos el signal con la última información validada por el servidor
        this.currentUser.set(data);
      })
    );
  }
}
