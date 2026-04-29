// src/app/shared/api/empleados.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

export interface UsuarioBaseInfo {
  nombre: string;
  email: string;
  telefono?: string;
  ci: string;
}

export interface SucursalBaseInfo {
  nombre: string;
}

export interface Empleado {
  id: number;
  usuario_id: number;
  sucursal_id?: number | null;
  especialidad?: string | null;
  disponible: boolean;
  latitud?: number | null;
  longitud?: number | null;
  usuario?: UsuarioBaseInfo;
  sucursal?: SucursalBaseInfo;
}

export interface EmpleadoCreateFull {
  nombre: string;
  email: string;
  password?: string;
  ci: string;
  telefono?: string;
  especialidad?: string;
  sucursal_id: number;
  latitud?: number;
  longitud?: number;
}

@Injectable({
  providedIn: 'root'
})
export class EmpleadosService {
  private http = inject(HttpClient);
  private apiUrl = `${environment.apiUrl}/empleados`;

  listarEmpleados(): Observable<Empleado[]> {
    return this.http.get<Empleado[]>(this.apiUrl);
  }

  getDisponiblesPorSucursal(sucursalId: number): Observable<Empleado[]> {
    return this.listarEmpleados().pipe(
      map(empleados => empleados.filter(e => e.sucursal_id === sucursalId && e.disponible))
    );
  }

  crearEmpleado(payload: EmpleadoCreateFull): Observable<Empleado> {
    return this.http.post<Empleado>(this.apiUrl, payload);
  }

  actualizarEmpleado(id: number, payload: any): Observable<Empleado> {
    return this.http.patch<Empleado>(`${this.apiUrl}/${id}`, payload);
  }

  eliminarEmpleado(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`);
  }
}
