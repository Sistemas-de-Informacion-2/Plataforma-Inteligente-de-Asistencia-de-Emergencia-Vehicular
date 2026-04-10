import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface SolicitudEmergencia {
  id: number;
  tipo_incidente: string;
  descripcion: string;
  prioridad: 'ALTA' | 'MEDIA' | 'BAJA';
  estado: string;
  ubicacion?: string;
  fecha?: string;
}

@Injectable({
  providedIn: 'root'
})
export class SolicitudesService {
  private readonly API_URL = 'http://localhost:8000/api/v1/solicitudes';

  constructor(private http: HttpClient) {}

  getPendientes(): Observable<SolicitudEmergencia[]> {
    return this.http.get<SolicitudEmergencia[]>(`${this.API_URL}/pendientes`);
  }

  aceptarSolicitud(id: number): Observable<any> {
    return this.http.patch(`${this.API_URL}/${id}/estado?estado=EN_PROCESO`, {});
  }
}
