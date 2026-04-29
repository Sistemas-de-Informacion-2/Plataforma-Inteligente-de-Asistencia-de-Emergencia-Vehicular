import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface PagoResponse {
  pago_id: number;
  orden_id: number;
  monto_total: number;
  comision: number;
  monto_taller: number;
}

export interface DeudaResponse {
  deuda_actual: number;
  limite: number;
  puede_aceptar_solicitudes: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class PagosService {
  private readonly PAGOS_URL = `${environment.apiUrl}/pagos`;

  constructor(private http: HttpClient) {}

  /** Crea un pago post-servicio ingresando el monto cobrado y el método. */
  crearPago(solicitudId: number, montoTotal: number, metodoPago: 'APP' | 'EFECTIVO' | 'QR' = 'APP'): Observable<PagoResponse> {
    return this.http.post<PagoResponse>(`${this.PAGOS_URL}/`, {
      solicitud_id: solicitudId,
      monto_total: montoTotal,
      metodo_pago: metodoPago
    });
  }

  /** Confirma que el cliente pagó en efectivo, sumando la deuda al admin. */
  confirmarEfectivo(pagoId: number): Observable<any> {
    return this.http.post(`${this.PAGOS_URL}/${pagoId}/efectivo`, {});
  }

  /** Consulta el estado de deuda del admin. */
  consultarDeuda(): Observable<DeudaResponse> {
    return this.http.get<DeudaResponse>(`${this.PAGOS_URL}/deuda`);
  }
}
