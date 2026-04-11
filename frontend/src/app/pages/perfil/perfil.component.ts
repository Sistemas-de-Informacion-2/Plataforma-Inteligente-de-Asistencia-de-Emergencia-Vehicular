import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-perfil',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="max-w-7xl mx-auto space-y-6 lg:space-y-8 animate-fade-in">
      <div>
        <h1 class="text-2xl md:text-3xl font-bold text-text-main tracking-tight">Perfil / Configuración</h1>
        <p class="text-text-muted mt-1 text-sm md:text-base">Preferencias visuales y reglas de negocio del taller.</p>
      </div>
      <div class="bg-surface-light border border-gray-100 rounded-2xl p-8 flex items-center justify-center text-text-muted mt-4">
        Pronto: Configuraciones
      </div>
    </div>
  `
})
export class PerfilComponent {}
