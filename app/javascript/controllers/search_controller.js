import { Controller } from "@hotwired/stimulus"

// Este controlador maneja la búsqueda en tiempo real con Turbo Frames
export default class extends Controller {
  static targets = ["input"]
  static values = {
    debounce: { type: Number, default: 300 }
  }
  
  connect() {
    this.timeout = null
    console.log("Controlador de búsqueda conectado")
  }
  
  // Búsqueda inmediata al enviar formulario (Enter)
  preventSubmit(event) {
    event.preventDefault()
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }
  
  // Búsqueda con debounce al escribir
  debouncedSubmit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.debounceValue)
  }
} 