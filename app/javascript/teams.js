console.log('🚀 Teams.js cargado');

// Módulo para la funcionalidad de equipos
window.TeamsModule = (function() {
  let selectedPlayer = null;
  let searchTimeout = null;
  
  // Configuración por defecto
  let config = {
    teamId: null,
    searchUrl: null,
    addPlayerUrl: null,
    removePlayerUrl: null,
    deleteTeamUrl: null
  };

  function init() {
    // Usar configuración de la vista si está disponible
    if (window.TEAM_CONFIG) {
      config = { ...config, ...window.TEAM_CONFIG };
    }
    
    console.log('🔧 TeamsModule inicializado con config:', config);
    setupEventListeners();
  }

  function setupEventListeners() {
    // Event listener para botones de hacer principal
    document.addEventListener('click', function(e) {
      console.log('🖱️ Click detectado en:', e.target);
      
      if (e.target.closest('.make-primary-btn')) {
        console.log('🎯 Click en botón make-primary-btn detectado');
        const button = e.target.closest('.make-primary-btn');
        const playerId = button.dataset.playerId;
        console.log('📋 Player ID:', playerId);
        makePlayerPrimary(playerId, e);
      }
    });

    // Cerrar modal al hacer clic fuera
    document.addEventListener('click', function(e) {
      const modal = document.getElementById('addPlayerModal');
      if (e.target === modal) {
        closeAddPlayerModal();
      }
      
      const deleteModal = document.getElementById('deleteTeamModal');
      if (e.target === deleteModal) {
        closeDeleteTeamModal();
      }
    });

    // Cerrar modal con tecla Escape
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        const modal = document.getElementById('addPlayerModal');
        if (modal && !modal.classList.contains('hidden')) {
          closeAddPlayerModal();
        }
        
        const deleteModal = document.getElementById('deleteTeamModal');
        if (deleteModal && !deleteModal.classList.contains('hidden')) {
          closeDeleteTeamModal();
        }
      }
    });
  }

  function openAddPlayerModal() {
    const modal = document.getElementById('addPlayerModal');
    if (modal) {
      modal.classList.remove('hidden');
      
      // Limpiar estado
      resetAddPlayerModal();
      
      // Enfocar en el input de búsqueda
      setTimeout(() => {
        const searchInput = document.getElementById('playerSearchInput');
        if (searchInput) {
          searchInput.focus();
        }
      }, 100);
    }
  }

  function closeAddPlayerModal() {
    const modal = document.getElementById('addPlayerModal');
    if (modal) {
      modal.classList.add('hidden');
      resetAddPlayerModal();
    }
  }

  function resetAddPlayerModal() {
    selectedPlayer = null;
    
    const searchInput = document.getElementById('playerSearchInput');
    const searchResults = document.getElementById('searchResults');
    const selectedInfo = document.getElementById('selectedPlayerInfo');
    const isPrimaryCheckbox = document.getElementById('isPrimaryTeam');
    const addBtn = document.getElementById('addPlayerBtn');
    
    if (searchInput) searchInput.value = '';
    if (searchResults) searchResults.classList.add('hidden');
    if (selectedInfo) selectedInfo.classList.add('hidden');
    if (isPrimaryCheckbox) isPrimaryCheckbox.checked = false;
    if (addBtn) addBtn.disabled = true;
  }

  function searchPlayers(query) {
    clearTimeout(searchTimeout);
    
    const searchResults = document.getElementById('searchResults');
    const playersSearchList = document.getElementById('playersSearchList');
    
    if (query.length < 2) {
      searchResults.classList.add('hidden');
      return;
    }
    
    searchTimeout = setTimeout(() => {
      fetch(`${config.searchUrl}?search=${encodeURIComponent(query)}`, {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
          'Accept': 'application/json'
        }
      })
      .then(response => response.json())
      .then(data => {
        if (data.success && data.players) {
          displaySearchResults(data.players);
          searchResults.classList.remove('hidden');
        } else {
          console.error('Error en búsqueda:', data.error);
          playersSearchList.innerHTML = '<div class="p-4 text-slate-400 text-center">No se encontraron jugadores</div>';
          searchResults.classList.remove('hidden');
        }
      })
      .catch(error => {
        console.error('Error buscando jugadores:', error);
        playersSearchList.innerHTML = '<div class="p-4 text-red-400 text-center">Error en la búsqueda</div>';
        searchResults.classList.remove('hidden');
      });
    }, 300);
  }

  function displaySearchResults(players) {
    const playersSearchList = document.getElementById('playersSearchList');
    
    if (players.length === 0) {
      playersSearchList.innerHTML = '<div class="p-4 text-slate-400 text-center">No se encontraron jugadores disponibles</div>';
      return;
    }
    
    playersSearchList.innerHTML = players.map(player => {
      // Manejar valores null o undefined
      const entrantName = (player.entrant_name || '').replace(/'/g, "\\'");
      const playerName = (player.name || '').replace(/'/g, "\\'");
      const displayName = player.name || player.entrant_name || 'Sin nombre';
      
      return `
        <div class="p-3 hover:bg-slate-600 cursor-pointer border-b border-slate-600 last:border-b-0 transition-colors"
             onclick="selectPlayer(${player.id}, '${entrantName}', '${playerName}')">
          <div class="flex items-center">
            <div class="w-8 h-8 rounded-full bg-gradient-to-r from-red-600 to-red-800 flex items-center justify-center border border-red-500 mr-3">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-slate-100" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />
              </svg>
            </div>
            <div>
              <div class="text-sm font-medium text-slate-200">${player.entrant_name || 'Sin nombre'}</div>
              <div class="text-xs text-slate-400">${displayName}</div>
            </div>
          </div>
        </div>
      `;
    }).join('');
  }

  function selectPlayer(playerId, entrantName, name) {
    selectedPlayer = {
      id: playerId,
      entrant_name: entrantName,
      name: name
    };
    
    const selectedInfo = document.getElementById('selectedPlayerInfo');
    const selectedDetails = document.getElementById('selectedPlayerDetails');
    const addBtn = document.getElementById('addPlayerBtn');
    const searchResults = document.getElementById('searchResults');
    
    // Manejar valores null o undefined para la visualización
    const displayEntrantName = entrantName || 'Sin nombre';
    const displayName = name || entrantName || 'Sin nombre';
    
    if (selectedDetails) {
      selectedDetails.innerHTML = `
        <div class="flex items-center">
          <div class="w-10 h-10 rounded-full bg-gradient-to-r from-red-600 to-red-800 flex items-center justify-center border border-red-500 mr-3">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-slate-100" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />
            </svg>
          </div>
          <div>
            <div class="font-medium text-slate-200">${displayEntrantName}</div>
            <div class="text-sm text-slate-400">${displayName}</div>
          </div>
        </div>
      `;
    }
    
    if (selectedInfo) selectedInfo.classList.remove('hidden');
    if (addBtn) addBtn.disabled = false;
    if (searchResults) searchResults.classList.add('hidden');
  }

  function addSelectedPlayer() {
    if (!selectedPlayer) return;
    
    const isPrimary = document.getElementById('isPrimaryTeam').checked;
    const addBtn = document.getElementById('addPlayerBtn');
    
    // Deshabilitar botón mientras se procesa
    addBtn.disabled = true;
    addBtn.textContent = 'Agregando...';
    
    fetch(config.addPlayerUrl, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        player_id: selectedPlayer.id,
        is_primary: isPrimary
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('✅ Jugador agregado exitosamente');
        closeAddPlayerModal();
        
        // Recargar la página para mostrar el jugador agregado
        if (data.reload_team) {
          window.location.reload();
        }
      } else {
        console.error('❌ Error agregando jugador:', data.error);
        alert('Error al agregar jugador: ' + data.error);
      }
    })
    .catch(error => {
      console.error('❌ Error en la solicitud:', error);
      alert('Error al agregar jugador');
    })
    .finally(() => {
      addBtn.disabled = false;
      addBtn.textContent = 'Agregar Jugador';
    });
  }

  function makePlayerPrimary(playerId, event) {
    try {
      console.log('🔄 Iniciando makePlayerPrimary con playerId:', playerId);
      
      if (!event) {
        console.error('❌ Event no está definido');
        alert('Error: Event no definido');
        return;
      }
      
      // Cambiar el botón a estado de carga
      const button = event.target.closest('button');
      if (!button) {
        console.error('❌ Botón no encontrado');
        alert('Error: Botón no encontrado');
        return;
      }
      
      const originalText = button.textContent;
      button.disabled = true;
      button.textContent = 'Procesando...';
      
      console.log('📡 Enviando solicitud POST...');
      
      fetch(config.addPlayerUrl, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          player_id: playerId,
          is_primary: true
        })
      })
      .then(response => {
        console.log('📡 Respuesta recibida:', response.status);
        return response.json();
      })
      .then(data => {
        console.log('📊 Datos recibidos:', data);
        if (data.success) {
          console.log('✅ Equipo principal actualizado exitosamente');
          if (data.reload_team) {
            window.location.reload();
          }
        } else {
          console.error('❌ Error actualizando equipo principal:', data.error);
          alert('Error al actualizar equipo principal: ' + data.error);
        }
      })
      .catch(error => {
        console.error('❌ Error en la solicitud:', error);
        alert('Error al actualizar equipo principal: ' + error.message);
      })
      .finally(() => {
        // Restaurar el botón
        button.disabled = false;
        button.textContent = originalText;
      });
    } catch (error) {
      console.error('❌ Error en makePlayerPrimary:', error);
      alert('Error inesperado: ' + error.message);
    }
  }

  function removePlayerFromTeam(playerId) {
    if (confirm('¿Está seguro de que desea remover este jugador del equipo?')) {
      fetch(config.removePlayerUrl, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          player_id: playerId
        })
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          console.log('✅ Jugador removido exitosamente');
          if (data.reload_team) {
            window.location.reload();
          }
        } else {
          console.error('❌ Error removiendo jugador:', data.error);
          alert('Error al remover jugador: ' + data.error);
        }
      })
      .catch(error => {
        console.error('❌ Error en la solicitud:', error);
        alert('Error al remover jugador');
      });
    }
  }

  function openDeleteTeamModal() {
    const modal = document.getElementById('deleteTeamModal');
    if (modal) {
      modal.classList.remove('hidden');
    }
  }

  function closeDeleteTeamModal() {
    const modal = document.getElementById('deleteTeamModal');
    if (modal) {
      modal.classList.add('hidden');
    }
  }

  function confirmDeleteTeam() {
    const deleteBtn = document.getElementById('deleteTeamBtn');
    const originalText = deleteBtn.textContent;
    
    // Deshabilitar botón y mostrar estado de carga
    deleteBtn.disabled = true;
    deleteBtn.textContent = 'Eliminando...';
    
    fetch(config.deleteTeamUrl, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('✅ Equipo eliminado exitosamente');
        
        // Mostrar mensaje de éxito y redirigir
        alert(`✅ ${data.message}`);
        
        if (data.redirect_url) {
          window.location.href = data.redirect_url;
        } else {
          window.location.href = '/teams';
        }
      } else {
        console.error('❌ Error eliminando equipo:', data.error);
        alert('❌ Error al eliminar equipo: ' + data.error);
      }
    })
    .catch(error => {
      console.error('❌ Error en la solicitud:', error);
      alert('❌ Error al eliminar equipo. Inténtelo nuevamente.');
    })
    .finally(() => {
      deleteBtn.disabled = false;
      deleteBtn.textContent = originalText;
    });
  }

  // API pública del módulo
  return {
    init: init,
    openAddPlayerModal: openAddPlayerModal,
    closeAddPlayerModal: closeAddPlayerModal,
    searchPlayers: searchPlayers,
    selectPlayer: selectPlayer,
    addSelectedPlayer: addSelectedPlayer,
    makePlayerPrimary: makePlayerPrimary,
    removePlayerFromTeam: removePlayerFromTeam,
    openDeleteTeamModal: openDeleteTeamModal,
    closeDeleteTeamModal: closeDeleteTeamModal,
    confirmDeleteTeam: confirmDeleteTeam
  };
})();

// Inicializar cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', function() {
  console.log('🔧 DOM cargado, inicializando TeamsModule...');
  window.TeamsModule.init();
});

// Hacer las funciones globales para compatibilidad con onclick
window.openAddPlayerModal = window.TeamsModule.openAddPlayerModal;
window.closeAddPlayerModal = window.TeamsModule.closeAddPlayerModal;
window.makePlayerPrimary = window.TeamsModule.makePlayerPrimary; 