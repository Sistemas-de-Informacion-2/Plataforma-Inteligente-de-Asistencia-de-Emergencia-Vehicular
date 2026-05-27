import { Injectable, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface NotificationItem {
  id: number;
  mensaje: string;
  leido: boolean;
  fecha: string;
  usuario_id: number;
}

@Injectable({
  providedIn: 'root'
})
export class NotificacionesService {
  private readonly NOTIFICACIONES_URL = `${environment.apiUrl}/notificaciones`;
  
  // Estado global para el drawer de notificaciones
  public isDrawerOpen = signal<boolean>(false);

  constructor(private http: HttpClient) {}

  /** Obtiene la lista de notificaciones del usuario autenticado.
  GET /api/v1/notificaciones/ */
  listarNotificaciones(soloNoLeidas: boolean = false, skip: number = 0, limit: number = 50): Observable<NotificationItem[]> {
    return this.http.get<NotificationItem[]>(`${this.NOTIFICACIONES_URL}/`, {
      params: {
        solo_no_leidas: soloNoLeidas.toString(),
        skip: skip.toString(),
        limit: limit.toString()
      }
    });
  }

  /** Cuenta la cantidad de notificaciones no leídas.
  GET /api/v1/notificaciones/no-leidas/contar */
  contarNoLeidas(): Observable<{ usuario_id: number; no_leidas_count: number }> {
    return this.http.get<{ usuario_id: number; no_leidas_count: number }>(`${this.NOTIFICACIONES_URL}/no-leidas/contar`);
  }

  /**Marca una notificación específica como leída.
  PUT /api/v1/notificaciones/{notificacion_id}/leer */
  marcarComoLeida(notificacionId: number): Observable<NotificationItem> {
    return this.http.put<NotificationItem>(`${this.NOTIFICACIONES_URL}/${notificacionId}/leer`, {});
  }

  /** Marca todas las notificaciones como leídas de una sola vez.
  PUT /api/v1/notificaciones/leer-todas */
  marcarTodasComoLeidas(): Observable<{ message: string; actualizadas: number }> {
    return this.http.put<{ message: string; actualizadas: number }>(`${this.NOTIFICACIONES_URL}/leer-todas`, {});
  }
}
