import { Component, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../../shared/api/auth.service';
import { MapSelectorComponent } from '../../../shared/ui/map-selector/map-selector.component';

@Component({
  selector: 'app-registro-taller',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule, MapSelectorComponent],
  templateUrl: './registro-taller.component.html',
  styleUrl: './registro-taller.component.css'
})
export class RegistroTallerComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);

  // Control de Pasos (1 a 3)
  currentStep = signal(1);
  isLoading = signal(false);
  successMessage = signal('');
  errorMessage = signal('');
  showPassword = signal(false);

  // Carousel de Beneficios (Senior Style)
  benefitImages = [
    'beneficios/b1.webp',
    'beneficios/b2.webp',
    'beneficios/b3.webp',
    'beneficios/b4.webp'
  ];
  currentBenefitIndex = signal(0);
  private benefitInterval: any;

  registroForm = this.fb.group({
    // Paso 1: Datos Personales
    nombre: ['', [Validators.required, Validators.minLength(3)]],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]],
    ci: ['', Validators.required],
    codigoPais: ['+591'],
    telefono: ['', [Validators.required, Validators.pattern(/^[0-9]+$/)]],
    
    // Paso 2: Datos del Taller
    nombre_taller: ['', Validators.required],
    descripcion_taller: ['', [Validators.maxLength(200)]],
    
    // Paso 3: Datos de la Sucursal
    nombre_sucursal: ['', Validators.required],
    direccion_sucursal: ['', Validators.required],
    latitud: [0, Validators.required],
    longitud: [0, Validators.required],
    telefono_sucursal: ['']
  });

  ngOnInit() {
    this.startBenefitCarousel();
  }

  ngOnDestroy() {
    this.stopBenefitCarousel();
  }

  private startBenefitCarousel() {
    this.benefitInterval = setInterval(() => {
      this.currentBenefitIndex.update(idx => (idx + 1) % this.benefitImages.length);
    }, 4000);
  }

  private stopBenefitCarousel() {
    if (this.benefitInterval) {
      clearInterval(this.benefitInterval);
    }
  }

  goToBenefit(index: number) {
    this.currentBenefitIndex.set(index);
    this.stopBenefitCarousel();
    this.startBenefitCarousel();
  }

  // Helpers de navegación
  nextStep() {
    if (this.canMoveToNextStep()) {
      this.currentStep.update(s => s + 1);
      this.errorMessage.set('');
    } else {
      this.errorMessage.set('Por favor, completa los campos obligatorios del paso actual.');
    }
  }

  prevStep() {
    this.currentStep.update(s => s - 1);
    this.errorMessage.set('');
  }

  canMoveToNextStep(): boolean {
    const form = this.registroForm;
    if (this.currentStep() === 1) {
      return !!(form.get('nombre')?.valid && form.get('email')?.valid && form.get('password')?.valid && form.get('ci')?.valid && form.get('telefono')?.valid);
    }
    if (this.currentStep() === 2) {
      return !!(form.get('nombre_taller')?.valid);
    }
    return true;
  }

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
      this.errorMessage.set('Revisa los datos del formulario.');
      return;
    }

    if (this.registroForm.value.latitud === 0 || this.registroForm.value.longitud === 0) {
      this.errorMessage.set('Debes marcar la ubicación de tu taller en el mapa.');
      return;
    }

    const formData = { ...this.registroForm.value };
    if (formData.telefono) {
      formData.telefono = `${formData.codigoPais} ${formData.telefono}`.trim();
    }
    delete formData.codigoPais;

    this.isLoading.set(true);
    this.errorMessage.set('');
    
    this.authService.registroOnboarding(formData).subscribe({
      next: () => {
        this.isLoading.set(false);
        this.successMessage.set('¡Bienvenido a FIXO! Redirigiendo al login...');
        setTimeout(() => this.router.navigate(['/login']), 2500);
      },
      error: (err) => {
        this.isLoading.set(false);
        this.errorMessage.set(err.error?.detail || 'Error al registrar taller.');
      }
    });
  }
}
