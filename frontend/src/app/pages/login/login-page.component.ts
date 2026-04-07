import { Component, inject } from '@angular/core';
import { Router } from '@angular/router';
import { LoginFormComponent } from '../../features/auth/ui/login-form/login-form.component';
import { AuthService } from '../../core/services/auth.service';
import { LoginCredentials } from '../../core/models/auth.model';

@Component({
  selector: 'app-login-page',
  standalone: true,
  imports: [LoginFormComponent],
  templateUrl: './login-page.component.html'
})
export class LoginPageComponent {
  private authService = inject(AuthService);
  private router = inject(Router);

  // Exponemos las Signals del state manager (AuthService) hacia la vista del contenedor
  public isLoading = this.authService.isLoading;
  public errorMsg = this.authService.errorMsg;

  /**
   * Manejador que recibe el evento emitido por el Dumb Component
   */
  public handleLogin(credentials: LoginCredentials): void {
    this.authService.login(credentials).subscribe({
      next: (response) => {
        // Redirección dinámica basada en los roles definidos
        switch (response.user.role) {
          case 'ADMINISTRADOR':
            this.router.navigate(['/admin']); // Ajusta estas rutas cuando crees el layout
            break;
          case 'PERSONAL':
            this.router.navigate(['/personal']);
            break;
          case 'CLIENTE':
            this.router.navigate(['/cliente']);
            break;
        }
      },
      error: () => {
        // No es necesario procesar el error visual porque el AuthService 
        // ya actualizó la señal 'errorMsg' capturada por nuestro Dumb Component
      }
    });
  }
}
