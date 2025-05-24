import { Controller } from "@hotwired/stimulus"

// Este controlador maneja la búsqueda en tiempo real con Turbo Frames
export default class extends Controller {
  static targets = ["input"]
  
  connect() {
    console.log("Search controller conectado")
    if (this.hasInputTarget) {
      console.log("Input encontrado:", this.inputTarget)
    }
  }
  
  // Método para prevenir el submit del formulario (Enter)
  preventSubmit(event) {
    console.log("PreventSubmit llamado")
    event.preventDefault()
    this.search()
  }
  
  // Método con debounce para escribir (compatibilidad con tournaments)
  debouncedSubmit(event) {
    console.log("DebouncedSubmit llamado con valor:", event.target.value)
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.search(), 300)
  }
  
  // Método específico para selects - sin debounce
  selectChanged(event) {
    console.log("Select cambió:", event.target.name, "=", event.target.value)
    this.search()
  }
  
  search() {
    console.log("=== Iniciando búsqueda ===")
    const form = this.element
    const formData = new FormData(form)
    
    // Construir parámetros de la URL con todos los campos del formulario
    const params = new URLSearchParams()
    for (let [key, value] of formData.entries()) {
      console.log(`Parámetro encontrado: ${key} = "${value}"`)
      if (value && value.trim() !== '') {
        params.append(key, value)
      }
    }
    params.append('partial', 'true')
    
    const url = `${form.action}?${params.toString()}`
    console.log("URL completa con todos los filtros:", url)
    
    fetch(url, {
      headers: {
        "Accept": "text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => {
      console.log("Respuesta recibida, status:", response.status)
      return response.text()
    })
    .then(html => {
      console.log("HTML recibido, longitud:", html.length)
      
      // Detectar si estamos en players o tournaments por la URL
      const isPlayersPage = form.action.includes('players')
      const frameId = isPlayersPage ? 'players_results' : 'tournaments_results'
      
      const frame = document.getElementById(frameId)
      if (frame) {
        console.log(`Frame ${frameId} encontrado, actualizando contenido`)
        frame.innerHTML = html
      } else {
        console.error(`Frame ${frameId} no encontrado`)
      }
    })
    .catch(error => {
      console.error('Error en fetch:', error)
    })
  }
  
  // Método para input changed (compatibilidad con players)
  inputChanged() {
    console.log("Input cambió")
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.search(), 300)
  }
} 