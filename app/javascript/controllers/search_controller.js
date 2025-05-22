import { Controller } from "@hotwired/stimulus"

// Este controlador maneja la búsqueda en tiempo real con Turbo Frames
export default class extends Controller {
  static targets = ["input", "form"]
  static values = {
    debounce: { type: Number, default: 300 }
  }
  
  connect() {
    this.timeout = null
    console.log("Controlador de búsqueda conectado")
  }
  
  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      // Con Turbo Frames, el foco se mantiene automáticamente
      this.formTarget.requestSubmit()
    }, this.debounceValue)
  }
} 