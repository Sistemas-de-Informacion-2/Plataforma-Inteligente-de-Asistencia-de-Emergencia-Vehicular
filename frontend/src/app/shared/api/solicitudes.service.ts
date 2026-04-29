// src/app/shared/api/solicitudes.service.ts
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface DiagnosticoIA {
  id: number;
  problema_detectado?: string;
  nivel_gravedad?: string;
  prioridad?: string;
  costo_estimado_ia?: number;
}

export interface Evidencia {
  id: number;
  tipo: string;
  url: string;
}

export interface Vehiculo {
  id: number;
  marca: string;
  modelo: string;
  anio: number;
  placa: string;
}

export interface SolicitudEmergencia {
  id: number;
  descripcion?: string;
  latitud?: number;
  longitud?: number;
  estado: string;
  fecha_creacion?: string;
  cliente_id?: number;
  vehiculo_id?: number;
  // Campos embebidos (SolicitudDetallada)
  evidencias?: Evidencia[];
  diagnostico?: DiagnosticoIA;
  vehiculo?: Vehiculo;
  // Campos de UI (agregados localmente)
  mecanicoSeleccionado?: number | null;
  montoCobro?: number | null;
  metodoPago?: 'APP' | 'EFECTIVO' | 'QR';
  mostrandoCobro?: boolean;
  // Campos legacy (usados por DashboardComponent)
  tipo_incidente?: string;
  prioridad?: 'ALTA' | 'MEDIA' | 'BAJA';
  ubicacion?: string;
  fecha?: string;
  resumen_ia?: string;
  clasificacion_ia?: string;
  [key: string]: any;
}

@Injectable({
  providedIn: 'root'
})
export class SolicitudesService {
  private readonly INCIDENTES_URL = `${environment.apiUrl}/incidentes`;
  private readonly SUCURSALES_URL = `${environment.apiUrl}/sucursales`;

  // URL legacy para DashboardComponent
  private readonly API_URL = `${environment.apiUrl}/solicitudes`;

  constructor(private http: HttpClient) {}

  /** Obtiene las solicitudes pendientes de aceptación para una sucursal.
   * Carga inicial del Panel de Despacho.
   * GET /api/v1/sucursales/{sucursalId}/solicitudes/pendientes
   */
  getPendientesPorSucursal(sucursalId: number): Observable<SolicitudEmergencia[]> {
    return this.http.get<SolicitudEmergencia[]>(
      `${this.SUCURSALES_URL}/${sucursalId}/solicitudes/pendientes`
    );
  }

  /** Obtiene las solicitudes en proceso (ya aceptadas, pendientes de cobro).
   * GET /api/v1/sucursales/{sucursalId}/solicitudes/en-proceso
   */
  getEnProcesoPorSucursal(sucursalId: number): Observable<SolicitudEmergencia[]> {
    return this.http.get<SolicitudEmergencia[]>(
      `${this.SUCURSALES_URL}/${sucursalId}/solicitudes/en-proceso`
    );
  }

  /** Obtiene las solicitudes atendidas (finalizadas).
   * GET /api/v1/sucursales/{sucursalId}/solicitudes/atendidas
   */
  getAtendidasPorSucursal(sucursalId: number): Observable<SolicitudEmergencia[]> {
    return this.http.get<SolicitudEmergencia[]>(
      `${this.SUCURSALES_URL}/${sucursalId}/solicitudes/atendidas`
    );
  }

  /** Obtiene el detalle completo de una solicitud (con evidencias y diagnóstico).
   * Usado cuando llega un WebSocket con solo el solicitud_id.
   * GET /api/v1/incidentes/{solicitudId}
   */
  getDetalleSolicitud(solicitudId: number): Observable<SolicitudEmergencia> {
    return this.http.get<SolicitudEmergencia>(
      `${this.INCIDENTES_URL}/${solicitudId}`
    );
  }

  /** Legacy: Obtiene solicitudes pendientes (estado PENDIENTE).
   * Usado por DashboardComponent.
   */
  getPendientes(): Observable<SolicitudEmergencia[]> {
    return this.http.get<SolicitudEmergencia[]>(`${this.API_URL}/pendientes`);
  }

  /** Envía la respuesta del taller (aceptar/rechazar).
   * POST /api/v1/sucursales/{sucursalId}/solicitudes/{solicitudId}/respuesta
   */
  responderSolicitud(
    sucursalId: number,
    solicitudId: number,
    payload: { aceptar: boolean; empleado_id?: number | null }
  ): Observable<any> {
    return this.http.post(
      `${this.SUCURSALES_URL}/${sucursalId}/solicitudes/${solicitudId}/respuesta`,
      payload
    );
  }
}
