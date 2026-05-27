// src/app/shared/api/pujas.service.ts
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Puja {
  id: number;
  solicitud_id: number;
  sucursal_id: number;
  precio_estimado: number;
  tiempo_llegada_minutos: number;
  estado: string;
  fecha: string;
}

export interface PujaEnriquecida {
  id: number;
  solicitud_id: number;
  sucursal_id: number;
  sucursal_nombre: string;
  taller_nombre: string;
  precio_estimado: number;
  tiempo_llegada_minutos: number;
  estado: string;
  rating: number;
  rating_count: number;
  distancia_km: number;
  fecha: string;
}

export interface PujasListResponse {
  solicitud_id: number;
  total_pujas: number;
  pujas: PujaEnriquecida[];
}

export interface PujaResponse {
  message: string;
  puja: Puja;
  datos_enriquecidos: {
    sucursal_nombre: string;
    taller_nombre: string;
    rating: number;
    rating_count: number;
    distancia_km: number;
  };
}

@Injectable({
  providedIn: 'root'
})
export class PujasService {
  private readonly PUJAS_URL = `${environment.apiUrl}/pujas`;

  constructor(private http: HttpClient) {}

  /**
   * Envía una puja (precio_estimado) para una solicitud de emergencia.
   * POST /api/v1/pujas/
   */
  crearPuja(solicitudId: number, precioEstimado: number): Observable<PujaResponse> {
    return this.http.post<PujaResponse>(`${this.PUJAS_URL}/`, {
      solicitud_id: solicitudId,
      precio_estimado: precioEstimado
    });
  }

  /**
   * Obtiene la lista de todas las pujas de una solicitud de emergencia.
   * GET /api/v1/pujas/{solicitud_id}
   */
  listarPujas(solicitudId: number): Observable<PujasListResponse> {
    return this.http.get<PujasListResponse>(`${this.PUJAS_URL}/${solicitudId}`);
  }
}
