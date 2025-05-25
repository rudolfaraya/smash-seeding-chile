import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "searchForm", "loadingIndicator"]
  static values = { 
    url: String,
    page: { type: Number, default: 1 },
    loading: { type: Boolean, default: false }
  }

  connect() {
    console.log("🎮 Players controller conectado")
    this.setupInfiniteScroll()
    this.setupSearchDebounce()
  }

  setupInfiniteScroll() {
    // Configurar scroll infinito para mejor UX
    this.scrollHandler = this.handleScroll.bind(this)
    window.addEventListener('scroll', this.scrollHandler, { passive: true })
  }

  setupSearchDebounce() {
    // Debounce para búsquedas más eficientes
    this.searchTimeout = null
  }

  disconnect() {
    if (this.scrollHandler) {
      window.removeEventListener('scroll', this.scrollHandler)
    }
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
  }

  search(event) {
    // Limpiar timeout anterior
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }

    // Debounce de 300ms para evitar búsquedas excesivas
    this.searchTimeout = setTimeout(() => {
      this.performSearch(event.target.value)
    }, 300)
  }

  performSearch(query) {
    if (this.loadingValue) return

    this.loadingValue = true
    this.showLoadingIndicator()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('query', query)
    url.searchParams.set('partial', 'true')

    fetch(url, {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      this.listTarget.innerHTML = html
      this.pageValue = 1 // Reset page counter
      this.hideLoadingIndicator()
    })
    .catch(error => {
      console.error('Error en búsqueda:', error)
      this.hideLoadingIndicator()
    })
    .finally(() => {
      this.loadingValue = false
    })
  }

  handleScroll() {
    // Implementar scroll infinito si es necesario
    if (this.loadingValue) return

    const scrollPosition = window.innerHeight + window.scrollY
    const documentHeight = document.documentElement.offsetHeight
    const threshold = 200 // pixels antes del final

    if (scrollPosition >= documentHeight - threshold) {
      this.loadNextPage()
    }
  }

  loadNextPage() {
    if (this.loadingValue) return

    this.loadingValue = true
    this.showLoadingIndicator()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('page', this.pageValue + 1)
    url.searchParams.set('partial', 'true')

    // Mantener query actual si existe
    const currentQuery = document.querySelector('[data-players-target="searchForm"] input')?.value
    if (currentQuery) {
      url.searchParams.set('query', currentQuery)
    }

    fetch(url, {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      if (html.trim()) {
        // Crear un elemento temporal para parsear el HTML
        const tempDiv = document.createElement('div')
        tempDiv.innerHTML = html
        
        // Extraer solo los elementos de jugadores
        const newPlayers = tempDiv.querySelectorAll('.player-card, .player-row')
        
        if (newPlayers.length > 0) {
          newPlayers.forEach(player => {
            this.listTarget.appendChild(player)
          })
          this.pageValue += 1
        }
      }
      this.hideLoadingIndicator()
    })
    .catch(error => {
      console.error('Error cargando página:', error)
      this.hideLoadingIndicator()
    })
    .finally(() => {
      this.loadingValue = false
    })
  }

  showLoadingIndicator() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove('hidden')
    }
  }

  hideLoadingIndicator() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('hidden')
    }
  }

  // Método para refrescar la lista completa
  refresh() {
    this.pageValue = 1
    this.performSearch('')
  }
} 