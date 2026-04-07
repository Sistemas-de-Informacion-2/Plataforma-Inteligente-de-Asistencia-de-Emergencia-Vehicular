import { Component, input, output } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { LoginCredentials } from '../../../../core/models/auth.model';

@Component({
  selector: 'app-login-form',
  standalone: true,
  imports: [ReactiveFormsModule, CommonModule],
  templateUrl: './login-form.component.html'
})
export class LoginFormComponent {
  // Entradas y Salidas basadas en Angular Signals (17.3+)
  public isLoading = input.required<boolean>();
  public errorMsg = input<string | null>(null);

  public loginSubmit = output<LoginCredentials>();

  public loginForm;

  constructor(private fb: FormBuilder) {
    this.loginForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(4)]]
    });
  }

  onSubmit(): void {
    if (this.loginForm.valid) {
      this.loginSubmit.emit(this.loginForm.getRawValue() as LoginCredentials);
    } else {
      // Forzar mostrar los errores visuales si el formulario es inválido
      this.loginForm.markAllAsTouched();
    }
  }
}
