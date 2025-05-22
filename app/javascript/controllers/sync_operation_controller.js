import { Controller } from "@hotwired/stimulus"

// Este controlador maneja las animaciones y estados durante la sincronización
export default class extends Controller {
  static targets = ["button", "spinner", "content", "container"]
  static values = {
    inProgress: Boolean
  }

  connect() {
    console.log("Controlador de operación de sincronización conectado")
  }

  // Inicia una operación de sincronización
  startSync(event) {
    // Solo mostrar el spinner si la petición no se completa instantáneamente
    this.inProgressValue = true
    this.updateUI()

    // Si el botón tiene un atributo href, navegar a esa URL
    const button = event.currentTarget
    const url = button.getAttribute('href')
    
    if (url) {
      // Evitar que el evento por defecto se ejecute inmediatamente
      event.preventDefault()
      
      // Enviar la solicitud con fetch para mantener el estado de la página
      fetch(url, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.getCSRFToken(),
          'Accept': 'text/vnd.turbo-stream.html'
        },
        credentials: 'same-origin'
      })
      .then(response => {
        if (!response.ok) {
          throw new Error('Error en la sincronización')
        }
        return response.text()
      })
      .then(html => {
        // Procesar la respuesta Turbo Stream
        Turbo.renderStreamMessage(html)
        this.finishSync()
      })
      .catch(error => {
        console.error('Error:', error)
        this.finishSync()
        this.showError()
      })
    }
  }

  finishSync() {
    this.inProgressValue = false
    this.updateUI()
  }
  
  showError() {
    // Mostrar mensaje de error
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add('sync-error')
      setTimeout(() => {
        this.containerTarget.classList.remove('sync-error')
      }, 3000)
    }
  }

  updateUI() {
    // Actualizar UI basado en el estado
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = this.inProgressValue
      this.buttonTarget.classList.toggle('opacity-50', this.inProgressValue)
      this.buttonTarget.classList.toggle('cursor-not-allowed', this.inProgressValue)
    }

    if (this.hasSpinnerTarget && this.hasContentTarget) {
      this.spinnerTarget.classList.toggle('hidden', !this.inProgressValue)
      this.contentTarget.classList.toggle('hidden', this.inProgressValue)
    }
  }
  
  getCSRFToken() {
    const metaTag = document.querySelector('meta[name="csrf-token"]')
    return metaTag ? metaTag.getAttribute('content') : ''
  }
} 