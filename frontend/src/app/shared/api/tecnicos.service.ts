// src/app/shared/api/tecnicos.service.ts
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Tecnico {
  id: number;
  nombre: string;
  especialidad: string;
  telefono: string;
  estado: 'DISPONIBLE' | 'OCUPADO' | 'INACTIVO';
}

@Injectable({
  providedIn: 'root'
})
export class TecnicosService {
  private readonly API_URL = `${environment.apiUrl}/usuarios/tecnicos`;

  constructor(private http: HttpClient) {}

  getTecnicos(): Observable<Tecnico[]> {
    return this.http.get<Tecnico[]>(this.API_URL);
  }

  crearTecnico(data: Partial<Tecnico>): Observable<Tecnico> {
    return this.http.post<Tecnico>(this.API_URL, data);
  }

  actualizarTecnico(id: number, data: Partial<Tecnico>): Observable<Tecnico> {
    return this.http.patch<Tecnico>(`${this.API_URL}/${id}`, data);
  }

  eliminarTecnico(id: number): Observable<any> {
    return this.http.delete(`${this.API_URL}/${id}`);
  }
}
