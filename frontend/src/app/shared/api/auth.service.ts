import { Injectable, signal, inject } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';

export interface LoginResponse {
  access_token: string;
  token_type: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);

  // Endpoint base de FastAPI
  private readonly API_URL = 'http://localhost:8000/api/v1';
  
  // Signals para manejar el estado de autenticación (isAuthenticated)
  public isAuthenticated = signal<boolean>(this.hasToken());

  login(username: string, password: string): Observable<LoginResponse> {
    const body = new HttpParams()
      .set('username', username)
      .set('password', password);

    const headers = new HttpHeaders({
      'Content-Type': 'application/x-www-form-urlencoded'
    });

    return this.http.post<LoginResponse>(`${this.API_URL}/auth/login`, body.toString(), { headers }).pipe(
      tap((response) => {
        if (response && response.access_token) {
          localStorage.setItem('access_token', response.access_token);
          this.isAuthenticated.set(true);
        }
      })
    );
  }

  registroOnboarding(data: any): Observable<any> {
    // Hace POST /api/v1/talleres/onboarding
    return this.http.post(`${this.API_URL}/talleres/onboarding`, data);
  }

  logout(): void {
    // Limpia localStorage, apaga las Signals y redirige a login
    localStorage.removeItem('access_token');
    this.isAuthenticated.set(false);
    this.router.navigate(['/login']);
  }

  private hasToken(): boolean {
    return typeof localStorage !== 'undefined' && !!localStorage.getItem('access_token');
  }

  isAdmin(): boolean {
    const token = localStorage.getItem('access_token');
    if (token) {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.roles && payload.roles.includes('ADMIN_TALLER');
    }
    return false;
  }

  isSuperAdmin(): boolean {
    const token = localStorage.getItem('access_token');
    if (token) {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.roles && payload.roles.includes('SUPER_ADMIN');
    }
    return false;
  }

  isTecnico(): boolean {
    const token = localStorage.getItem('access_token');
    if (token) {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.roles && payload.roles.includes('TECNICO');
    }
    return false;
  }

}
