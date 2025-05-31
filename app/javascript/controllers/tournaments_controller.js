import { Controller } from "@hotwired/stimulus"

// Controlador para manejar la funcionalidad de torneos
export default class extends Controller {
  static targets = ["eventRow", "toggleButton", "filterForm", "queryInput", "regionSelect", "citySelect", "eventCount", "seedCount", "attendeeCount", "hasSeedsFilter", "resultCount", "quickFilter"]
  static values = { tournamentId: Number }

  connect() {
    console.log("Controlador de torneos conectado")
    // Inicializar el estado de todos los botones de toggle de eventos
    this.initializeEventStates()
    this.setupImageOptimizations()
    this.lastQuery = ""
    this.debounceTimer = null

    if (this.hasQuickFilterTarget) {
      this.quickFilterTarget.addEventListener('click', this.handleQuickFilter.bind(this))
    }
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  // Método para aplicar filtros automáticamente cuando cambian las fechas
  applyFilters(event) {
    console.log("Aplicando filtros automáticamente...")
    const form = event.target.closest('form')
    if (form) {
      // Enviar el formulario automáticamente
      form.requestSubmit()
    }
  }

  // Método para inicializar el estado correcto de los eventos y botones
  initializeEventStates() {
    // Buscar todos los botones de toggle de eventos en escritorio
    const desktopButtons = document.querySelectorAll('[id^="toggle-events-"]')
    desktopButtons.forEach(button => {
      const tournamentId = button.dataset.tournamentId
      const eventRows = document.querySelectorAll(`tr.event-row[data-tournament-id="${tournamentId}"]`)
      
      // Verificar si los eventos están ocultos (que es el estado inicial correcto)
      const allHidden = Array.from(eventRows).every(row => row.classList.contains('hidden'))
      
      if (allHidden) {
        // Estado correcto: eventos ocultos, botón debe decir "Ver Eventos"
        button.dataset.state = 'closed'
        const span = button.querySelector('span')
        if (span) span.textContent = 'Ver Eventos'
        
        const icon = button.querySelector('.toggle-icon')
        if (icon) {
          icon.innerHTML = `<path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />`
        }
        button.classList.remove('bg-blue-700')
      }
    })
    
    // Buscar todos los botones de toggle de eventos en móvil
    const mobileButtons = document.querySelectorAll('[id^="toggle-events-mobile-"]')
    mobileButtons.forEach(button => {
      const tournamentId = button.dataset.tournamentId
      const eventsContainer = document.querySelector(`#mobile-events-${tournamentId}`)
      
      if (eventsContainer && eventsContainer.classList.contains('hidden')) {
        // Estado correcto: eventos ocultos, botón debe decir "Ver Eventos"
        button.dataset.state = 'closed'
        const span = button.querySelector('span')
        if (span) span.textContent = 'Ver Eventos'
        
        const icon = button.querySelector('.toggle-icon-mobile')
        if (icon) {
          icon.style.transform = 'rotate(0deg)'
        }
      }
    })
  }

  // Método para alternar la visibilidad de eventos de escritorio
  toggleEvents(event) {
    const button = event.currentTarget
    const tournamentId = button.dataset.tournamentId
    const currentState = button.dataset.state
    
    console.log(`Toggling events for tournament ${tournamentId}, current state: ${currentState}`)
    
    // Buscar todas las filas de eventos para este torneo
    const eventRows = document.querySelectorAll(`tr[data-tournament-id="${tournamentId}"]`)
    const icon = button.querySelector('.toggle-icon')
    const span = button.querySelector('span')
    
    if (currentState === 'closed') {
      // Mostrar eventos
      eventRows.forEach(row => {
        row.classList.remove('hidden')
        row.classList.add('fade-in')
      })
      
      // Cambiar el icono a "arriba"
      if (icon) {
        icon.innerHTML = `<path fill-rule="evenodd" d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z" clip-rule="evenodd" />`
      }
      
      if (span) span.textContent = 'Ocultar Eventos'
      button.dataset.state = 'open'
      button.classList.add('bg-blue-700')
    } else {
      // Ocultar eventos
      eventRows.forEach(row => {
        row.classList.add('hidden')
        row.classList.remove('fade-in')
      })
      
      // Cambiar el icono a "abajo"
      if (icon) {
        icon.innerHTML = `<path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />`
      }
      
      if (span) span.textContent = 'Ver Eventos'
      button.dataset.state = 'closed'
      button.classList.remove('bg-blue-700')
    }
  }

  // Método para alternar la visibilidad de eventos en móvil
  toggleEventsMobile(event) {
    const button = event.currentTarget
    const tournamentId = button.dataset.tournamentId
    const currentState = button.dataset.state
    
    console.log(`Toggling mobile events for tournament ${tournamentId}, current state: ${currentState}`)
    
    // Buscar el contenedor de eventos móvil
    const eventsContainer = document.querySelector(`#mobile-events-${tournamentId}`)
    const icon = button.querySelector('.toggle-icon-mobile')
    const span = button.querySelector('span')
    
    if (currentState === 'closed') {
      // Mostrar eventos
      if (eventsContainer) {
        eventsContainer.classList.remove('hidden')
        eventsContainer.classList.add('fade-in-down')
      }
      
      // Cambiar el icono
      if (icon) {
        icon.style.transform = 'rotate(180deg)'
      }
      
      if (span) span.textContent = 'Ocultar Eventos'
      button.dataset.state = 'open'
    } else {
      // Ocultar eventos
      if (eventsContainer) {
        eventsContainer.classList.add('hidden')
        eventsContainer.classList.remove('fade-in-down')
      }
      
      // Cambiar el icono
      if (icon) {
        icon.style.transform = 'rotate(0deg)'
      }
      
      if (span) span.textContent = 'Ver Eventos'
      button.dataset.state = 'closed'
    }
  }

  // Optimizaciones para imágenes remotas de start.gg
  setupImageOptimizations() {
    // Configurar Intersection Observer para lazy loading
    if ('IntersectionObserver' in window) {
      const imageObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const img = entry.target
            this.loadRemoteImage(img)
            observer.unobserve(img)
          }
        })
      }, {
        rootMargin: '50px 0px',
        threshold: 0.1
      })

      // Observar todas las imágenes remotas
      document.querySelectorAll('img[data-src]').forEach(img => {
        imageObserver.observe(img)
      })
    }

    // Preload imágenes de torneos visibles
    this.preloadVisibleBanners()
  }

  loadRemoteImage(img) {
    const src = img.dataset.src
    if (!src) return

    // Crear un nuevo elemento imagen para precargar
    const tempImg = new Image()
    
    tempImg.onload = () => {
      img.src = src
      img.classList.remove('image-skeleton')
      img.classList.add('remote-image')
      img.style.opacity = '1'
    }

    tempImg.onerror = () => {
      // Mostrar fallback si la imagen falla
      const fallback = img.dataset.fallback || img.alt || '🏆'
      img.parentElement.innerHTML = `
        <div class="w-full h-full image-fallback flex items-center justify-center text-xs font-semibold">
          ${fallback}
        </div>
      `
    }

    // Iniciar la carga
    tempImg.src = src
  }

  preloadVisibleBanners() {
    // Precargar las primeras 5 imágenes de banners para mejorar perceived performance
    const visibleImages = document.querySelectorAll('.tournament-row img[src*="start.gg"], .tournament-card img[src*="start.gg"]')
    
    Array.from(visibleImages).slice(0, 5).forEach(img => {
      const link = document.createElement('link')
      link.rel = 'preload'
      link.as = 'image'
      link.href = img.src
      document.head.appendChild(link)
    })
  }

  // Cache de imágenes para evitar recargas
  cacheRemoteImage(url) {
    if (!this.imageCache) {
      this.imageCache = new Map()
    }

    if (!this.imageCache.has(url)) {
      const img = new Image()
      img.src = url
      this.imageCache.set(url, img)
    }

    return this.imageCache.get(url)
  }

  // Resto de la funcionalidad existente
  search(event) {
    if (event) event.preventDefault()

    const query = this.queryInputTarget.value.trim()
    
    if (query === this.lastQuery) return

    this.lastQuery = query

    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    this.debounceTimer = setTimeout(() => {
      this.performSearch()
    }, 300)
  }

  async performSearch() {
    const formData = new FormData(this.filterFormTarget)
    
    try {
      const response = await fetch('/tournaments', {
        method: 'POST',
        body: formData,
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        
        // Reconfigurar optimizaciones de imagen después de actualizar contenido
        setTimeout(() => {
          this.setupImageOptimizations()
        }, 100)
      }
    } catch (error) {
      console.error('Error en búsqueda:', error)
    }
  }

  clearFilters(event) {
    event.preventDefault()
    
    this.queryInputTarget.value = ""
    this.regionSelectTarget.value = ""
    this.citySelectTarget.value = ""
    this.eventCountTarget.value = ""
    this.seedCountTarget.value = ""
    this.attendeeCountTarget.value = ""
    this.hasSeedsFilterTarget.value = ""
    
    this.lastQuery = ""
    this.performSearch()
  }

  // Quick filters para usabilidad mejorada
  handleQuickFilter(event) {
    const button = event.target.closest('[data-filter]')
    if (!button) return

    event.preventDefault()
    
    const filterType = button.dataset.filter
    
    // Limpiar filtros existentes
    this.clearCurrentFilters()
    
    // Aplicar filtro específico
    switch(filterType) {
      case 'recent':
        // Los torneos ya vienen ordenados por fecha reciente
        break
      case 'with-seeds':
        this.hasSeedsFilterTarget.value = 'true'
        break
      case 'large':
        this.attendeeCountTarget.value = '32'
        break
      case 'online':
        this.regionSelectTarget.value = 'Online'
        break
    }

    this.performSearch()
  }

  clearCurrentFilters() {
    this.regionSelectTarget.value = ""
    this.citySelectTarget.value = ""
    this.eventCountTarget.value = ""
    this.seedCountTarget.value = ""
    this.attendeeCountTarget.value = ""
    this.hasSeedsFilterTarget.value = ""
  }

  regionChanged() {
    const selectedRegion = this.regionSelectTarget.value
    
    if (selectedRegion === "Online") {
      this.citySelectTarget.value = ""
      this.citySelectTarget.disabled = true
    } else {
      this.citySelectTarget.disabled = false
    }
    
    this.search()
  }
}

// Mantener compatibilidad con funciones globales existentes
window.toggleEvents = function(tournamentId) {
  console.log("Función global toggleEvents llamada para torneo:", tournamentId)
  const button = document.getElementById(`toggle-events-${tournamentId}`)
  if (button) {
    button.click()
  }
} 