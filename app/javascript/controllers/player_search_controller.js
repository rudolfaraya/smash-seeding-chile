import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "results", "selectedPlayer", "selectedPlayerInfo", "playerIdField", "submitButton"]
  
  connect() {
    console.log("Player search controller conectado")
    this.searchTimeout = null
    this.selectedPlayer = null
    this.updateSubmitButton()
  }

  search() {
    const query = this.searchInputTarget.value.trim()
    console.log("Input detectado:", query)
    
    clearTimeout(this.searchTimeout)
    
    if (query.length < 2) {
      this.hideResults()
      this.selectedPlayer = null
      this.updateSubmitButton()
      return
    }
    
    this.searchTimeout = setTimeout(() => {
      console.log("Iniciando búsqueda para:", query)
      this.searchPlayers(query)
    }, 300)
  }

  async searchPlayers(query) {
    console.log("Función searchPlayers llamada con:", query)
    
    // Mostrar indicador de carga
    this.resultsTarget.innerHTML = '<div class="p-4 text-center text-slate-400">🔍 Buscando jugadores...</div>'
    this.showResults()
    
    const url = `/user_player_requests/search_players?query=${encodeURIComponent(query)}`
    console.log("URL de búsqueda:", url)
    
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.getCSRFToken(),
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'same-origin'
      })
      
      console.log("Respuesta recibida:", response.status)
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      console.log("Datos recibidos:", data)
      this.displayResults(data)
      
    } catch (error) {
      console.error("Error en búsqueda:", error)
      this.resultsTarget.innerHTML = `
        <div class="p-4 text-center text-red-400">
          ❌ Error: ${error.message}
        </div>
      `
      this.showResults()
    }
  }

  displayResults(data) {
    console.log("Mostrando resultados:", data)
    
    if (!data.players || data.players.length === 0) {
      this.resultsTarget.innerHTML = '<div class="p-4 text-center text-slate-400">❌ No se encontraron jugadores</div>'
      this.showResults()
      return
    }
    
    const resultsHtml = data.players.map(player => `
      <div class="player-result p-3 border-b border-slate-600 hover:bg-slate-600 cursor-pointer transition-colors duration-200 last:border-b-0" 
           data-action="click->player-search#selectPlayer" 
           data-player-id="${player.id}"
           data-player-tag="${player.tag || player.display_name || player.entrant_name}"
           data-player-name="${player.full_name || player.name || 'Sin nombre'}">
        <div class="font-medium text-slate-100">${player.tag || player.display_name || player.entrant_name}</div>
        <div class="text-sm text-slate-400">${player.full_name || player.name || 'Sin nombre'}</div>
        <div class="text-xs text-slate-500">${player.tournaments_count || 0} torneos • ${player.events_count || 0} eventos</div>
      </div>
    `).join('')
    
    this.resultsTarget.innerHTML = resultsHtml
    this.showResults()
  }

  selectPlayer(event) {
    const playerElement = event.currentTarget
    const playerId = playerElement.dataset.playerId
    const playerTag = playerElement.dataset.playerTag
    const playerName = playerElement.dataset.playerName
    
    console.log("Jugador seleccionado:", playerId, playerTag)
    
    this.selectedPlayer = { id: playerId, tag: playerTag, name: playerName }
    this.playerIdFieldTarget.value = playerId
    this.searchInputTarget.value = playerTag
    
    // Ocultar resultados y mostrar jugador seleccionado
    this.hideResults()
    
    if (this.hasSelectedPlayerTarget && this.hasSelectedPlayerInfoTarget) {
      this.selectedPlayerInfoTarget.innerHTML = `
        <div>
          <h3 class="font-medium text-slate-100">${playerTag}</h3>
          <p class="text-sm text-slate-400">${playerName}</p>
        </div>
      `
      this.selectedPlayerTarget.classList.remove('hidden')
    }
    
    this.updateSubmitButton()
  }

  clearSelection() {
    console.log("Limpiando selección")
    this.selectedPlayer = null
    this.playerIdFieldTarget.value = ''
    this.searchInputTarget.value = ''
    
    if (this.hasSelectedPlayerTarget) {
      this.selectedPlayerTarget.classList.add('hidden')
    }
    
    this.hideResults()
    this.updateSubmitButton()
  }

  showResults() {
    this.resultsTarget.classList.remove('hidden')
  }

  hideResults() {
    this.resultsTarget.classList.add('hidden')
  }

  updateSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      if (this.selectedPlayer) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.classList.remove('bg-slate-600')
        this.submitButtonTarget.classList.add('bg-red-600', 'hover:bg-red-700')
      } else {
        this.submitButtonTarget.disabled = true
        this.submitButtonTarget.classList.add('bg-slate-600')
        this.submitButtonTarget.classList.remove('bg-red-600', 'hover:bg-red-700')
      }
    }
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
} 