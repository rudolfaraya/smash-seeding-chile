import { Controller } from "@hotwired/stimulus"

// Este controlador maneja los mensajes flash
export default class extends Controller {
  static values = {
    removeAfter: Number
  }

  connect() {
    // Iniciar el temporizador para eliminar el mensaje automáticamente
    if (this.hasRemoveAfterValue) {
      this.timeout = setTimeout(() => {
        this.remove()
      }, this.removeAfterValue)
    }
  }

  disconnect() {
    // Limpiar el temporizador si existe
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  // Eliminar el mensaje flash
  remove() {
    this.element.classList.add('opacity-0')
    this.element.style.transition = 'opacity 0.5s ease'
    
    // Después de la animación, remover el elemento del DOM
    setTimeout(() => {
      this.element.remove()
    }, 500)
  }
} 