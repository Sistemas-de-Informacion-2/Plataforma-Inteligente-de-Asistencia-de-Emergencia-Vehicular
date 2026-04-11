import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

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
  password?: string; // Necesario para crear, no se devuelve
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
  private apiUrl = 'http://localhost:8000/api/v1/empleados';

  listarEmpleados(): Observable<Empleado[]> {
    return this.http.get<Empleado[]>(this.apiUrl);
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
