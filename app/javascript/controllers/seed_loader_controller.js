import { Controller } from "@hotwired/stimulus"

// Este controlador maneja la carga de seeds para un evento específico
export default class extends Controller {
  static values = {
    url: String,
    tournamentId: Number,
    eventId: Number,
    loaded: { type: Boolean, default: false }
  }

  static targets = ["button"]

  connect() {
    console.log("Controlador de Seed Loader conectado", this.element);
  }

  // Carga o alterna la visibilidad de los seeds
  toggle(event) {
    event.preventDefault();
    
    console.log("Toggle seeds para evento:", this.eventIdValue);
    
    // Obtener la fila de seeds - ahora usando el ID correcto según la vista
    const seedRow = document.getElementById(`seedsRow-${this.tournamentIdValue}-${this.eventIdValue}`);
    console.log("Fila de seeds:", seedRow);
    
    // Alternar el ícono del botón
    this.toggleButtonIcon();
    
    // Si ya está cargado, solo alternar visibilidad
    if (this.loadedValue && seedRow) {
      this.toggleVisibility(seedRow);
      return;
    }
    
    // Si la fila existe pero no está cargada, cargar los datos
    this.loadSeeds(seedRow);
  }
  
  // Cargar los datos de seeds
  async loadSeeds(seedRow) {
    if (!seedRow) {
      console.error("No se encontró la fila de seeds");
      return;
    }
    
    // Obtener el contenedor donde irán los datos
    const container = seedRow.querySelector(`#event-seeds-${this.eventIdValue}`);
    if (!container) {
      console.error("No se encontró el contenedor de seeds");
      return;
    }
    
    // Mostrar indicador de carga
    container.innerHTML = `
      <div class="flex justify-center p-4">
        <div class="flex items-center">
          <svg class="animate-spin h-4 w-4 text-red-500 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="text-slate-300 text-xs">Cargando seeds...</span>
        </div>
      </div>
    `;
    
    // Mostrar la fila si está oculta
    if (seedRow.classList.contains('hidden')) {
      seedRow.classList.remove('hidden');
      seedRow.style.display = 'table-row';
      void seedRow.offsetHeight; // Forzar reflow
      seedRow.classList.add('fade-in-down');
    }
    
    try {
      console.log("Cargando desde URL:", this.urlValue);
      
      // Usar fetch nativo para cargar los datos
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'text/html, application/xhtml+xml',
          'X-Requested-With': 'XMLHttpRequest'
        }
      });
      
      if (!response.ok) {
        throw new Error(`Error de red: ${response.status}`);
      }
      
      // Obtener el HTML de la respuesta
      const html = await response.text();
      console.log("Respuesta recibida:", html.substring(0, 100) + "...");
      
      // Actualizar el contenedor con los datos recibidos
      container.innerHTML = html;
      
      // Marcar como cargado
      this.loadedValue = true;
      
      // Aplicar clases al botón para indicar estado activo
      this.element.classList.add('active-button');
      
    } catch (error) {
      console.error("Error al cargar los seeds:", error);
      
      // Mostrar mensaje de error
      container.innerHTML = `
        <div class="p-4 bg-red-900/50 text-slate-200 rounded-lg border border-red-600 my-2">
          <div class="flex items-center">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-red-300 mr-2" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
            <span class="text-sm">Error al cargar los seeds. Por favor intenta de nuevo.</span>
          </div>
        </div>
      `;
    }
  }
  
  // Alternar visibilidad de la fila de seeds
  toggleVisibility(row) {
    if (row.classList.contains('hidden')) {
      // Mostrar
      row.classList.remove('hidden');
      row.style.display = 'table-row';
      void row.offsetHeight; // Forzar reflow
      row.classList.add('fade-in-down');
      setTimeout(() => row.classList.remove('fade-in-down'), 300);
      
      // Activar botón
      this.element.classList.add('active-button');
    } else {
      // Ocultar
      row.classList.add('fade-out-up');
      setTimeout(() => {
        row.classList.add('hidden');
        row.style.display = 'none';
        row.classList.remove('fade-out-up');
      }, 300);
      
      // Desactivar botón
      this.element.classList.remove('active-button');
    }
  }
  
  // Alternar icono del botón
  toggleButtonIcon() {
    const icon = this.element.querySelector('.toggle-icon');
    if (icon) {
      icon.classList.toggle('rotate-180');
    }
  }
} 