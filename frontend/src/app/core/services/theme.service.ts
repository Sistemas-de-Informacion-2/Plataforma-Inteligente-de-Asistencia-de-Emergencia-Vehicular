import { Injectable, Inject } from '@angular/core';
import { DOCUMENT } from '@angular/common';
import { BehaviorSubject, Observable } from 'rxjs';

export interface ThemePreferences {
  theme: 'light' | 'dark' | 'system';
  fontSize: 'sm' | 'md' | 'lg';
}

@Injectable({
  providedIn: 'root'
})
export class ThemeService {
  private configSubject = new BehaviorSubject<ThemePreferences>({
    theme: 'light',
    fontSize: 'md'
  });

  public preferences$: Observable<ThemePreferences> = this.configSubject.asObservable();

  constructor(@Inject(DOCUMENT) private document: Document) {
    this.initTheme();
  }

  /**
   * Método preparado para cargar configuración inicial (ej. desde localStorage o JSON remoto)
   */
  public initTheme(): void {
    // Aquí se leería el JSON o localStorage a futuro
    const defaultPrefs: ThemePreferences = { theme: 'light', fontSize: 'md' };
    this.setPreferences(defaultPrefs);
  }

  public setPreferences(prefs: ThemePreferences): void {
    this.configSubject.next(prefs);
    this.applyThemeToDOM(prefs);
  }

  private applyThemeToDOM(prefs: ThemePreferences): void {
    const root = this.document.documentElement;
    
    // Aplicación del tema oscuro/claro clásico usando clase en el elemento raíz
    if (prefs.theme === 'dark') {
      root.classList.add('theme-dark');
    } else {
      root.classList.remove('theme-dark');
    }
    
    // Ejemplo de inyección dinámica de una variable CSS (útil si viene de un JSON remoto personalizado)
    // root.style.setProperty('--primary-500', '#10b981'); 

    // Aplicación del tamaño de fuente a través del body o html 
    // root.style.fontSize = prefs.fontSize === 'sm' ? '14px' : prefs.fontSize === 'lg' ? '18px' : '16px';
  }
}
