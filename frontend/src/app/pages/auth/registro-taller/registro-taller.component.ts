import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../../shared/api/auth.service';
import { MapSelectorComponent } from '../../../shared/ui/map-selector/map-selector.component';

@Component({
  selector: 'app-registro-taller',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule, MapSelectorComponent],
  templateUrl: './registro-taller.component.html'
})
export class RegistroTallerComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);

  registroForm = this.fb.group({
    // Datos Personales
    nombre: ['', Validators.required],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]],
    ci: ['', Validators.required],
    codigoPais: ['+591'],
    telefono: [''],
    
    // Datos del Taller
    nombre_taller: ['', Validators.required],
    descripcion_taller: [''],
    
    // Datos de la Sucursal
    nombre_sucursal: ['', Validators.required],
    direccion_sucursal: [''],
    latitud: [0, Validators.required],
    longitud: [0, Validators.required],
    telefono_sucursal: ['']
  });

  isLoading = false;
  successMessage = '';
  errorMessage = '';

  onLocationSelected(location: { lat: number, lng: number } | null) {
    if (location) {
      this.registroForm.patchValue({
        latitud: location.lat,
        longitud: location.lng
      });
    }
  }

  onSubmit() {
    if (this.registroForm.invalid) {
      this.registroForm.markAllAsTouched();
      return;
    }

    // Verificar si capturó la ubicación
    if (this.registroForm.value.latitud === 0 && this.registroForm.value.longitud === 0) {
      this.errorMessage = 'Debe seleccionar una ubicación en el mapa.';
      return;
    }

    const formData = { ...this.registroForm.value };
    // Concatenar el código de país si hay un teléfono
    if (formData.telefono) {
      formData.telefono = `${formData.codigoPais} ${formData.telefono}`.trim();
    }
    // Removemos codigoPais del payload a enviar al backend
    delete formData.codigoPais;

    this.isLoading = true;
    this.errorMessage = '';
    
    this.authService.registroOnboarding(formData).subscribe({
      next: () => {
        this.isLoading = false;
        this.successMessage = 'Registro exitoso. Redirigiendo al login...';
        setTimeout(() => {
          this.router.navigate(['/login']);
        }, 2000);
      },
      error: (err) => {
        this.isLoading = false;
        this.errorMessage = err.error?.detail || 'Hubo un error al registrar. Revisa los datos o intenta de nuevo.';
        console.error('Error in onboarding:', err);
      }
    });
  }
}
