import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-sucursales',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="max-w-7xl mx-auto space-y-6 lg:space-y-8 animate-fade-in">
      <div>
        <h1 class="text-2xl md:text-3xl font-bold text-text-main tracking-tight">Gestión de Sucursales</h1>
        <p class="text-text-muted mt-1 text-sm md:text-base">Listado operativo de los talleres centralizados.</p>
      </div>
      <div class="bg-surface-light border border-gray-100 rounded-2xl p-8 flex items-center justify-center text-text-muted mt-4">
        Pronto: Panel de Sucursales
      </div>
    </div>
  `
})
export class SucursalesComponent {}
