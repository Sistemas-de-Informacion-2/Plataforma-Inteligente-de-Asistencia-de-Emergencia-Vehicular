import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Sucursal {
  id: number;
  nombre: string;
  direccion: string | null;
  latitud: number | null;
  longitud: number | null;
  telefono: string | null;
  taller_id: number;
}

export interface SucursalCreatePayload {
  nombre: string;
  direccion?: string;
  latitud: number;
  longitud: number;
  telefono?: string;
  taller_id: number;
}

@Injectable({
  providedIn: 'root'
})
export class SucursalesService {
  private http = inject(HttpClient);
  private apiTallerUrl = 'http://localhost:8000/api/v1/talleres';

  // Usamos Observable simple para mantener FSD. La UI usará Signals internamente.
  
  getMisTalleres(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiTallerUrl}/mis-talleres`);
  }

  listarSucursales(tallerId: number): Observable<Sucursal[]> {
    return this.http.get<Sucursal[]>(`${this.apiTallerUrl}/${tallerId}/sucursales`);
  }

  crearSucursal(tallerId: number, payload: SucursalCreatePayload): Observable<Sucursal> {
    return this.http.post<Sucursal>(`${this.apiTallerUrl}/${tallerId}/sucursales`, payload);
  }

  actualizarSucursal(sucursalId: number, payload: Partial<SucursalCreatePayload>): Observable<Sucursal> {
    return this.http.patch<Sucursal>(`${this.apiTallerUrl}/sucursales/${sucursalId}`, payload);
  }

  eliminarSucursal(sucursalId: number): Observable<void> {
    return this.http.delete<void>(`${this.apiTallerUrl}/sucursales/${sucursalId}`);
  }
}
