import { Injectable, signal } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable, tap, catchError, throwError } from 'rxjs';

export interface LoginResponse {
  access_token: string;
  token_type: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private readonly API_URL = 'http://localhost:8000/api/v1/auth/login';
  
  // Usamos Signals para manejar el estado de autenticación de forma reactiva sincronizada
  public isAuthenticated = signal<boolean>(this.hasToken());

  constructor(private http: HttpClient) {}

  login(username: string, password: string): Observable<LoginResponse> {
    // FastAPI (OAuth2PasswordRequestForm) requiere application/x-www-form-urlencoded
    const body = new HttpParams()
      .set('username', username)
      .set('password', password);

    const headers = new HttpHeaders({
      'Content-Type': 'application/x-www-form-urlencoded'
    });

    return this.http.post<LoginResponse>(this.API_URL, body.toString(), { headers }).pipe(
      tap((response) => {
        if (response && response.access_token) {
          localStorage.setItem('access_token', response.access_token);
          this.isAuthenticated.set(true); // Actualizamos el signal exitosamente
        }
      }),
      catchError(error => {
        // En una app real, aquí se enviarían métricas o logs globales
        return throwError(() => error);
      })
    );
  }

  logout(): void {
    localStorage.removeItem('access_token');
    this.isAuthenticated.set(false);
  }

  private hasToken(): boolean {
    // Aquí podríamos agregar además lógica de verificación de expiración del JWT (jwt-decode)
    return typeof localStorage !== 'undefined' && !!localStorage.getItem('access_token');
  }
}
