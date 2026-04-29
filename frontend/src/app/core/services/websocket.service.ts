// src/app/core/services/websocket.service.ts
import { Injectable } from '@angular/core';
import { Observable, Subject } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface EmergencyNotification {
  type: string;
  solicitud_id?: number;
  sucursal_id?: number;
  latitud?: number;
  longitud?: number;
  [key: string]: any;
}

@Injectable({
  providedIn: 'root'
})
export class WebsocketService {
  private notificationsSubject = new Subject<EmergencyNotification>();
  private ws: WebSocket | null = null;

  constructor() {}

  public connect(): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      return;
    }

    if (typeof localStorage === 'undefined') return;
    const token = localStorage.getItem('access_token');
    if (!token) {
      console.warn('[WS] No access_token in localStorage — skipping connect');
      return;
    }

    // El backend extrae el userId del token, NO del path.
    // Ruta backend: /api/v1/ws/notificaciones/?token=...
    const wsUrl = `${environment.wsUrl}/ws/notificaciones/?token=${token}`;
    console.log('[WS] Conectando a:', wsUrl.substring(0, 60) + '...');
    this.ws = new WebSocket(wsUrl);

    this.ws.onopen = () => {
      console.log('[WS] ✅ Conexión WebSocket establecida exitosamente');
    };

    this.ws.onmessage = (event) => {
      try {
        const data: EmergencyNotification = JSON.parse(event.data);
        console.log('[WS] Mensaje recibido:', data);
        this.notificationsSubject.next(data);
      } catch (e) {
        console.error('[WS] Error parsing WS message', e);
      }
    };

    this.ws.onerror = (error) => {
      console.error('[WS] ❌ WebSocket Error:', error);
    };

    this.ws.onclose = (event) => {
      console.log(`[WS] Conexión cerrada (code=${event.code}, reason=${event.reason})`);
    };
  }

  public getNotifications(): Observable<EmergencyNotification> {
    this.connect();
    return this.notificationsSubject.asObservable();
  }

  public disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}
