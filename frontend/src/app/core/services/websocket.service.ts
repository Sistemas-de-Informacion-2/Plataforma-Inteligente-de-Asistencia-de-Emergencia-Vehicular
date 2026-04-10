import { Injectable } from '@angular/core';
import { Observable, Subject } from 'rxjs';

export interface EmergencyNotification {
  id: string;
  type: string;
  priority: 'low' | 'medium' | 'high';
  message: string;
}

@Injectable({
  providedIn: 'root'
})
export class WebsocketService {
  private notificationsSubject = new Subject<EmergencyNotification>();

  constructor() {
    // Simulación de conexión y recepción de alertas para el ejemplo base
    // En un entorno real aquí nos conectaríamos con FastAPI vía WebSockets
    // o usando Server-Sent Events (SSE).
    setInterval(() => {
      // Simula recibir un evento aleatorio solo para propósitos demostrativos
      if(Math.random() > 0.8) {
         this.notificationsSubject.next({
           id: Math.random().toString(36).substring(7),
           type: 'Problema de batería',
           priority: 'medium',
           message: 'Un usuario necesita asistencia técnica cerca de su ubicación.'
         });
      }
    }, 10000);
  }

  public getNotifications(): Observable<EmergencyNotification> {
    return this.notificationsSubject.asObservable();
  }
}
