// src/app/shared/api/servicios.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Servicio {
  id: number;
  nombre: string;
  descripcion: string | null;
}

@Injectable({
  providedIn: 'root'
})
export class ServiciosService {
  private http = inject(HttpClient);
  private apiUrl = `${environment.apiUrl}/servicios`;

  getServicios(): Observable<Servicio[]> {
    return this.http.get<Servicio[]>(this.apiUrl);
  }
}
