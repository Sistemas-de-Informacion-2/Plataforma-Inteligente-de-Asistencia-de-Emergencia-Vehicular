import { Component, OnInit, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { SucursalesService, Sucursal } from '../../shared/api/sucursales.service';
import { MapSelectorComponent } from '../../shared/ui/map-selector/map-selector.component';

@Component({
  selector: 'app-sucursales',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, MapSelectorComponent],
  templateUrl: './sucursales.component.html'
})
export class SucursalesComponent implements OnInit {
  private sucursalesService = inject(SucursalesService);
  private fb = inject(FormBuilder);

  constructor() {
    console.log('SucursalesComponent instanciado');
  }

  // Estado via Signals
  tallerId = signal<number | null>(null);
  sucursales = signal<Sucursal[]>([]);
  isLoading = signal(true);
  isModalOpen = signal(false);
  isSubmitting = signal(false);
  editingId = signal<number | null>(null);
  viewingSucursal = signal<Sucursal | null>(null);
  
  // Validation error handling para el mapa
  locationError = signal(false);

  sucursalForm!: FormGroup;

  ngOnInit(): void {
    this.initForm();
    this.loadData();
  }

  private initForm(): void {
    this.sucursalForm = this.fb.group({
      nombre: ['', Validators.required],
      direccion: [''],
      telefono: [''],
      latitud: [null, Validators.required],
      longitud: [null, Validators.required]
    });
  }

  private loadData(): void {
    this.isLoading.set(true);
    this.sucursalesService.getMisTalleres().subscribe({
      next: (talleres) => {
        if (talleres && talleres.length > 0) {
          const tId = talleres[0].id;
          this.tallerId.set(tId);
          this.fetchSucursales(tId);
        } else {
          this.isLoading.set(false);
          console.warn('El usuario no tiene ningún taller asociado.');
        }
      },
      error: (err) => {
        console.error('Error obteniendo mis talleres', err);
        this.isLoading.set(false);
      }
    });
  }

  private fetchSucursales(tId: number): void {
    this.sucursalesService.listarSucursales(tId).subscribe({
      next: (data) => {
        this.sucursales.set(data);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Error listando sucursales', err);
        this.isLoading.set(false);
      }
    });
  }

  openModal(sucursal?: Sucursal): void {
    this.locationError.set(false);
    this.viewingSucursal.set(null);

    if (sucursal) {
      this.editingId.set(sucursal.id);
      this.sucursalForm.patchValue({
        nombre: sucursal.nombre,
        direccion: sucursal.direccion,
        telefono: sucursal.telefono,
        latitud: sucursal.latitud,
        longitud: sucursal.longitud
      });
    } else {
      this.editingId.set(null);
      this.sucursalForm.reset();
    }
    this.isModalOpen.set(true);
  }

  openViewModal(sucursal: Sucursal): void {
    this.viewingSucursal.set(sucursal);
    this.isModalOpen.set(true);
  }

  closeModal(): void {
    this.isModalOpen.set(false);
    this.viewingSucursal.set(null);
    this.editingId.set(null);
  }

  eliminarSucursal(id: number): void {
    if (confirm('¿Estás seguro de que deseas eliminar esta sucursal?')) {
      this.sucursalesService.eliminarSucursal(id).subscribe({
        next: () => {
          this.sucursales.update(current => current.filter(s => s.id !== id));
        },
        error: (err) => console.error('Error al eliminar sucursal', err)
      });
    }
  }

  onLocationSelected(location: {lat: number, lng: number} | null): void {
    if (location) {
      this.sucursalForm.patchValue({
        latitud: location.lat,
        longitud: location.lng
      });
      this.locationError.set(false);
    } else {
      this.sucursalForm.patchValue({
        latitud: null,
        longitud: null
      });
    }
  }

  onSubmit(): void {
    if (this.viewingSucursal()) return; 

    if (this.sucursalForm.invalid) {
      this.sucursalForm.markAllAsTouched();
      if (!this.sucursalForm.get('latitud')?.value || !this.sucursalForm.get('longitud')?.value) {
        this.locationError.set(true);
      }
      return;
    }

    const tId = this.tallerId();
    if (!tId) return;

    this.isSubmitting.set(true);
    const payload = {
      ...this.sucursalForm.value,
      taller_id: tId
    };

    const isEditing = this.editingId() !== null;

    if (isEditing) {
      this.sucursalesService.actualizarSucursal(this.editingId()!, payload).subscribe({
        next: (updatedSucursal) => {
          this.sucursales.update(current => 
            current.map(s => s.id === updatedSucursal.id ? updatedSucursal : s)
          );
          this.isSubmitting.set(false);
          this.closeModal();
        },
        error: (err) => {
          console.error('Error actualizando sucursal', err);
          this.isSubmitting.set(false);
        }
      });
    } else {
      this.sucursalesService.crearSucursal(tId, payload).subscribe({
        next: (nuevaSucursal) => {
          this.sucursales.update(current => [...current, nuevaSucursal]);
          this.isSubmitting.set(false);
          this.closeModal();
        },
        error: (err) => {
          console.error('Error creando sucursal', err);
          this.isSubmitting.set(false);
        }
      });
    }
  }
}
