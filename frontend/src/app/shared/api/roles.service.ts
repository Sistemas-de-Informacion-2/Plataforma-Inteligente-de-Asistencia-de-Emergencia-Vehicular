import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Permiso {
  id: number;
  nombre: string;
  descripcion?: string;
}

export interface Rol {
  id: number;
  nombre: string;
  permisos: Permiso[];
}

export interface RolCreate {
  nombre: string;
  permisos_ids: number[];
}

export interface RolUpdate {
  nombre?: string;
  permisos_ids?: number[];
}

@Injectable({
  providedIn: 'root'
})
export class RolesService {
  private readonly URL = `${environment.apiUrl}/admin/roles`;

  constructor(private http: HttpClient) {}

  getRoles(): Observable<Rol[]> {
    return this.http.get<Rol[]>(`${this.URL}/`);
  }

  getPermisos(): Observable<Permiso[]> {
    return this.http.get<Permiso[]>(`${this.URL}/permisos/`);
  }

  createRol(rol: RolCreate): Observable<Rol> {
    return this.http.post<Rol>(`${this.URL}/`, rol);
  }

  updateRol(id: number, rol: RolUpdate): Observable<Rol> {
    return this.http.put<Rol>(`${this.URL}/${id}`, rol);
  }

  deleteRol(id: number): Observable<void> {
    return this.http.delete<void>(`${this.URL}/${id}`);
  }
}
