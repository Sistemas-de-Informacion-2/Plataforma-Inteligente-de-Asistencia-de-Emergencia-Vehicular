import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { MapSelectorComponent } from '../../../shared/ui/map-selector/map-selector.component';

@Component({
  selector: 'app-registro-sucursal',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, MapSelectorComponent],
  templateUrl: './registro-sucursal.component.html'
})
export class RegistroSucursalComponent {
  public form: FormGroup;
  public isSubmitting = false;

  constructor(private fb: FormBuilder, private router: Router) {
    // Modelado estricto basado en taller.py -> class Sucursal (nombre, direccion, latitud, longitud, telefono)
    this.form = this.fb.group({
      nombre: ['', [Validators.required, Validators.maxLength(150)]],
      direccion: ['', [Validators.maxLength(300)]],
      telefono: ['', [Validators.maxLength(20)]],
      latitud: [null, Validators.required],
      longitud: [null, Validators.required]
    });
  }

  // Listener para capturar el punto del mapa emitido por <app-map-selector>
  onLocationSelected(coords: { lat: number, lng: number } | null) {
    if (coords) {
      this.form.patchValue({
        latitud: coords.lat,
        longitud: coords.lng
      });
      // Marcaremos como touched silenciosamente para disparar validación si el usuario ya intentó enviar
      this.form.get('latitud')?.markAsTouched();
    } else {
      this.form.patchValue({ latitud: null, longitud: null });
    }
  }

  onSubmit() {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.isSubmitting = true;
    const payload = this.form.value;

    console.log('Payload validado para FastAPI (PostGIS):', payload);
    // Acá iría: this.sucursalesService.crear(payload).subscribe(...)
    
    // Simulación de respuesta exitosa
    setTimeout(() => {
      this.isSubmitting = false;
      this.router.navigate(['/dashboard']);
    }, 1200);
  }
}
