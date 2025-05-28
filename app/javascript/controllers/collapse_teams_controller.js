import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon", "loading", "players"]
  static values = { 
    teamsUrl: String 
  }

  connect() {
    console.log("CollapseTeams controller connected")
    this.loadedTeams = new Set()
  }

  toggleTeam(event) {
    const teamId = event.params.teamId
    const contentTarget = this.getTarget(`content${teamId}`)
    const iconTarget = this.getTarget(`icon${teamId}`)
    
    console.log(`Toggling team ${teamId}`)
    
    if (contentTarget.classList.contains('hidden')) {
      // Mostrar contenido
      contentTarget.classList.remove('hidden')
      iconTarget.classList.add('rotate-180')
      
      // Cargar jugadores si no se han cargado antes
      if (!this.loadedTeams.has(teamId)) {
        this.loadTeamPlayers(teamId)
      }
    } else {
      // Ocultar contenido
      contentTarget.classList.add('hidden')
      iconTarget.classList.remove('rotate-180')
    }
  }

  async loadTeamPlayers(teamId) {
    const loadingTarget = this.getTarget(`loading${teamId}`)
    const playersTarget = this.getTarget(`players${teamId}`)
    
    try {
      console.log(`Loading players for team ${teamId}`)
      
      // Mostrar loading
      loadingTarget.classList.remove('hidden')
      playersTarget.classList.add('hidden')
      
      // Hacer petición para obtener los jugadores del equipo
      const response = await fetch(`/teams/${teamId}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      
      // Crear HTML para los jugadores
      const playersHTML = this.createPlayersHTML(data.players)
      playersTarget.innerHTML = playersHTML
      
      // Ocultar loading y mostrar jugadores
      loadingTarget.classList.add('hidden')
      playersTarget.classList.remove('hidden')
      
      // Marcar como cargado
      this.loadedTeams.add(teamId)
      
    } catch (error) {
      console.error('Error loading team players:', error)
      
      // Mostrar error
      loadingTarget.innerHTML = `
        <div class="text-center py-4">
          <div class="text-red-400 text-sm">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 inline mr-1" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
            Error al cargar jugadores
          </div>
        </div>
      `
    }
  }

  createPlayersHTML(players) {
    if (!players || players.length === 0) {
      return `
        <div class="text-center py-4 text-slate-500">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
          <div class="text-sm">No hay jugadores en este equipo</div>
        </div>
      `
    }

    return players.map(player => `
      <div class="flex items-center justify-between p-3 bg-slate-700 rounded-lg border border-slate-600 hover:border-slate-500 transition-colors">
        <div class="flex items-center space-x-3">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 rounded-full bg-slate-600 border border-slate-500 flex items-center justify-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-slate-300" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />
              </svg>
            </div>
          </div>
          <div>
            <div class="flex items-center space-x-2">
              <span class="text-sm font-medium text-slate-200">${player.entrant_name || player.name}</span>
              ${player.is_primary ? '<span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-blue-900 text-blue-200">Principal</span>' : ''}
            </div>
            ${player.name && player.name !== player.entrant_name ? `<div class="text-xs text-slate-400">${player.name}</div>` : ''}
          </div>
        </div>
        <div class="flex items-center space-x-2 text-xs text-slate-400">
          <span>${player.events_count || 0} eventos</span>
          <span>•</span>
          <span>${player.tournaments_count || 0} torneos</span>
        </div>
      </div>
    `).join('')
  }

  getTarget(name) {
    return this.targets.find(name) || this.element.querySelector(`[data-collapse-teams-target="${name}"]`)
  }
} 