import { Component, signal, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../shared/api/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.css'
})
export class LoginComponent implements OnInit, OnDestroy {
  loginForm: FormGroup;
  isLoading = false;
  errorMessage = '';
  showPassword = false;

  // Carousel de Publicidad (Signals - Angular 18)
  adImages = [
    'promo/fixo.webp',
    'promo/mecanico.webp',
  ];
  currentAdIndex = signal(0);
  private adInterval?: ReturnType<typeof setInterval>;

  constructor(
    private fb: FormBuilder,
    private authService: AuthService,
    private router: Router
  ) {
    this.loginForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(4)]]
    });
  }

  ngOnInit() {
    this.startAdCarousel();
  }

  ngOnDestroy() {
    this.stopAdCarousel();
  }

  goToAd(index: number) {
    this.currentAdIndex.set(index);
    this.stopAdCarousel();
    this.startAdCarousel();
  }

  private startAdCarousel() {
    this.adInterval = setInterval(() => {
      this.currentAdIndex.update(idx => (idx + 1) % this.adImages.length);
    }, 3000);
  }

  private stopAdCarousel() {
    if (this.adInterval) {
      clearInterval(this.adInterval);
    }
  }

  togglePasswordVisibility() {
    this.showPassword = !this.showPassword;
  }

  onSubmit() {
    if (this.loginForm.invalid) {
      this.loginForm.markAllAsTouched();
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    const { email, password } = this.loginForm.value;

    this.authService.login(email, password).subscribe({
      next: () => {
        this.isLoading = false;
        if (this.authService.isAdmin()) {
          this.router.navigate(['/despacho']);
        } else if (this.authService.isSuperAdmin()) {
          this.router.navigate(['/super-admin']);
        } else if (this.authService.isTecnico()) {
          // Si tuvieras un portal para técnicos:
          // this.router.navigate(['/tecnico']);
          console.warn('Técnico login: no hay dashboard de técnico web aún');
        } else {
          this.router.navigate(['/login']);
        }
      },
      error: (err) => {
        this.isLoading = false;
        this.errorMessage = 'Credenciales inválidas. Verifica tu correo y contraseña.';
        console.error('Error de Auth:', err);
      }
    });
  }
}
