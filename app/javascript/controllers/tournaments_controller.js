import { Controller } from "@hotwired/stimulus"

// Controlador para manejar la funcionalidad de torneos
export default class extends Controller {
  static targets = ["eventRow", "toggleButton"]
  static values = { tournamentId: Number }

  connect() {
    console.log("Controlador de torneos conectado")
    // Inicializar el estado de todos los botones de toggle de eventos
    this.initializeEventStates()
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
}

// Mantener compatibilidad con funciones globales existentes
window.toggleEvents = function(tournamentId) {
  console.log("Función global toggleEvents llamada para torneo:", tournamentId)
  const button = document.getElementById(`toggle-events-${tournamentId}`)
  if (button) {
    button.click()
  }
} 