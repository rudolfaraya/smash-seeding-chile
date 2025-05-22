import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = {
    url: String,
    loaded: Boolean,
    tournamentId: Number,
    eventId: Number
  }
  
  connect() {
    this.loadedValue = false
  }
  
  toggle() {
    const seedsRow = document.getElementById(`seedsRow-${this.tournamentIdValue}-${this.eventIdValue}`)
    const button = this.element
    
    if (seedsRow.classList.contains('hidden')) {
      seedsRow.classList.remove('hidden')
      button.textContent = 'Ocultar Seeds'
      
      // Solo cargar los seeds la primera vez
      if (!this.loadedValue) {
        this.load()
      }
    } else {
      seedsRow.classList.add('hidden')
      button.textContent = 'Ver Seeds'
    }
  }
  
  load() {
    const contentElement = document.getElementById(`event-seeds-${this.eventIdValue}`)
    
    contentElement.innerHTML = `
      <div class="flex justify-center p-4">
        <svg class="animate-spin h-6 w-6 text-green-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>
    `
    
    fetch(this.urlValue)
      .then(response => response.text())
      .then(html => {
        contentElement.innerHTML = html
        this.loadedValue = true
      })
      .catch(error => {
        contentElement.innerHTML = `
          <div class="p-4 text-center">
            <p class="text-red-500">Error al cargar los seeds: ${error.message}</p>
          </div>
        `
      })
  }
} 