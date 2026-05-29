// src/app/shared/ui/map-selector/map-selector.component.ts
import { Component, AfterViewInit, OnDestroy, Output, EventEmitter, Inject, PLATFORM_ID, Input, signal, inject, ViewChild, ElementRef } from '@angular/core';
import { CommonModule, isPlatformBrowser } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import * as L from 'leaflet';

@Component({
  selector: 'app-map-selector',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './map-selector.component.html',
  styles: [`
    .map-container {
      height: 100%;
      width: 100%;
      z-index: 10;
    }
  `]
})
export class MapSelectorComponent implements AfterViewInit, OnDestroy {
  @Input() readonly: boolean = false;
  @Input() fixedLocation: {lat: number, lng: number} | null = null;
  
  @Output() locationSelected = new EventEmitter<{lat: number, lng: number} | null>();

  @ViewChild('mapElement') mapElement!: ElementRef<HTMLDivElement>;

  private map!: L.Map;
  private currentMarker: L.Marker | null = null;
  private isBrowser: boolean;
  private http = inject(HttpClient);
  
  public searchQuery = signal('');
  public isSearching = signal(false);

  constructor(@Inject(PLATFORM_ID) platformId: Object) {
    this.isBrowser = isPlatformBrowser(platformId);
  }

  ngAfterViewInit(): void {
    if (!this.isBrowser) return; // Fix SSR
    // Pequeño timeout para asegurar que el contenedor esté renderizado
    setTimeout(() => {
      this.initMap();
    }, 50);
  }

  private initMap(): void {
    if (!this.mapElement || !this.mapElement.nativeElement) return;
    
    // Si el mapa ya existe (caso de re-renderizado rápido), lo limpiamos primero
    if (this.map) {
      this.map.remove();
    }

    // Configuración Iconos
    const iconRetinaUrl = 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png';
    const iconUrl = 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png';
    const shadowUrl = 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png';
    
    const iconDefault = L.icon({
      iconRetinaUrl, iconUrl, shadowUrl,
      iconSize: [25, 41], iconAnchor: [12, 41],
      popupAnchor: [1, -34], tooltipAnchor: [16, -28], shadowSize: [41, 41]
    });
    L.Marker.prototype.options.icon = iconDefault;

    // Ubicaciones
    const initialLat = this.fixedLocation?.lat || -17.7833;
    const initialLng = this.fixedLocation?.lng || -63.1821;

    // Desactivamos UX properties si el mapa es readonly (solo lectura)
    this.map = L.map(this.mapElement.nativeElement, {
      center: [initialLat, initialLng],
      zoom: 14,
      dragging: !this.readonly,
      scrollWheelZoom: !this.readonly,
      doubleClickZoom: !this.readonly,
      boxZoom: !this.readonly,
      keyboard: !this.readonly,
      zoomControl: !this.readonly // Quitar botones de +/-
    });

    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
      maxZoom: 19,
      attribution: '&copy; Carto'
    }).addTo(this.map);

    if (!this.readonly) {
      this.map.on('click', (e: L.LeafletMouseEvent) => {
        this.placeMarker(e.latlng.lat, e.latlng.lng);
      });
    }

    if (this.fixedLocation) {
      this.placeMarker(initialLat, initialLng);
    }
  }

  private placeMarker(lat: number, lng: number): void {
    if (this.currentMarker) {
      this.currentMarker.setLatLng([lat, lng]);
    } else {
      this.currentMarker = L.marker([lat, lng], { draggable: !this.readonly }).addTo(this.map);
      
      if (!this.readonly) {
        this.currentMarker.on('dragend', () => {
          const pos = this.currentMarker!.getLatLng();
          this.emitLocation(pos.lat, pos.lng);
        });
      }
    }
    
    this.map.setView([lat, lng], this.map.getZoom(), { animate: true });
    
    if (!this.readonly) {
      this.emitLocation(lat, lng);
    }
  }

  public removeMarker(): void {
    if (this.readonly) return;
    if (this.currentMarker && this.map) {
      this.map.removeLayer(this.currentMarker);
      this.currentMarker = null;
      this.locationSelected.emit(null);
    }
  }

  public locateMe(): void {
    if (this.readonly) return;
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          this.placeMarker(position.coords.latitude, position.coords.longitude);
        },
        (error) => {
          console.error('Error obteniendo ubicación', error);
        }
      );
    }
  }

  public buscarDireccion(): void {
    if (this.readonly) return;
    if (!this.searchQuery().trim()) return;

    this.isSearching.set(true);
    const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(this.searchQuery())}`;

    this.http.get<any[]>(url).subscribe({
      next: (res) => {
        this.isSearching.set(false);
        if (res && res.length > 0) {
          const firstResult = res[0];
          const lat = parseFloat(firstResult.lat);
          const lon = parseFloat(firstResult.lon);
          
          this.map.flyTo([lat, lon], 16, { animate: true, duration: 1.5 });
          
          // Solo colocar el pin después de la animación de vuelo de 1.5s
          setTimeout(() => {
            this.placeMarker(lat, lon);
          }, 1500);

        } else {
          // Mostrar feedback (podría ser un toast, por ahora en consola)
          console.warn('No se encontraron resultados para la dirección.');
        }
      },
      error: (err) => {
        this.isSearching.set(false);
        console.error('Error buscando dirección:', err);
      }
    });
  }

  private emitLocation(lat: number, lng: number): void {
    const payload = { lat: Number(lat.toFixed(6)), lng: Number(lng.toFixed(6)) };
    this.locationSelected.emit(payload);
  }

  ngOnDestroy(): void {
    if (this.map) {
      this.map.remove();
    }
  }
}
