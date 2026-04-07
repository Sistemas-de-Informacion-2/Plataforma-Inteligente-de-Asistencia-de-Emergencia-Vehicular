import { Injectable, signal, computed } from '@angular/core';
import { Observable, timer, throwError, of } from 'rxjs';
import { switchMap, tap } from 'rxjs/operators';
import { User, LoginCredentials, AuthResponse, Role } from '../models/auth.model';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  // Signals para el estado global (Transversal)
  public currentUser = signal<User | null>(null);
  public isLoading = signal<boolean>(false);
  public errorMsg = signal<string | null>(null);

  // Computed signals para selectores reactivos útiles
  public isLoggedIn = computed(() => this.currentUser() !== null);
  public userRole = computed(() => this.currentUser()?.role || null);

  constructor() {
    this.checkInitialSession();
  }

  /**
   * Mock global del Login para Simulación FSD.
   * Utiliza RxJS para emular 1.5s de latencia de red en Éxito y Error.
   * Modifica el estado nativo de Angular Signals en su interior.
   */
  public login(credentials: LoginCredentials): Observable<AuthResponse> {
    this.isLoading.set(true);
    this.errorMsg.set(null);

    return timer(1500).pipe( // Simula el delay de red de 1.5s
      switchMap(() => {
        // Mock Roles y Usuarios hardcodeados
        if (credentials.email === 'admin@sistema.com' && credentials.password === 'admin123') {
          return of(this.generateMockResponse('1', 'Admin Principal', credentials.email, 'ADMINISTRADOR'));
        } else if (credentials.email === 'personal@sistema.com' && credentials.password === 'personal123') {
          return of(this.generateMockResponse('2', 'Usuario Personal', credentials.email, 'PERSONAL'));
        } else if (credentials.email === 'cliente@sistema.com' && credentials.password === 'cliente123') {
          return of(this.generateMockResponse('3', 'Cliente Ejemplo', credentials.email, 'CLIENTE'));
        }
        
        return throwError(() => new Error('Credenciales inválidas. Por favor, verifique su correo o contraseña.'));
      }),
      tap({
        next: (response) => {
          this.currentUser.set(response.user);
          this.isLoading.set(false);
          // Mock persistencia de sesión
          localStorage.setItem('auth_token', response.token);
          localStorage.setItem('auth_user', JSON.stringify(response.user));
        },
        error: (err: Error) => {
          this.errorMsg.set(err.message);
          this.isLoading.set(false);
        }
      })
    );
  }

  /**
   * Limpia señales reactivas y almacenamiento local
   */
  public logout(): void {
    this.currentUser.set(null);
    this.errorMsg.set(null);
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_user');
  }

  /**
   * Recupera la sesión al refrescar la web para mantener reactividad de Signals
   */
  private checkInitialSession(): void {
    const storedUser = localStorage.getItem('auth_user');
    if (storedUser) {
      try {
        this.currentUser.set(JSON.parse(storedUser));
      } catch (e) {
        this.logout();
      }
    }
  }

  /**
   * Generador de Token JWT Mock para respuestas y persistencia
   */
  private generateMockResponse(id: string, name: string, email: string, role: Role): AuthResponse {
    return {
      user: { id, name, email, role },
      token: `mock-jwt-token-for-${role.toLowerCase()}-${Date.now()}`
    };
  }
}
