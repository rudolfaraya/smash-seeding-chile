// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

//console.log("Stimulus application loaded:", window.Stimulus)

// Función para mostrar/ocultar eventos de un torneo
window.toggleEvents = function(tournamentId) {
  const eventRows = document.querySelectorAll(`.event-row[data-tournament-id="${tournamentId}"]`);
  
  eventRows.forEach(row => {
    if (row.classList.contains('hidden')) {
      row.classList.remove('hidden');
    } else {
      row.classList.add('hidden');
      
      // También ocultar las filas de seeds asociadas a este torneo cuando se colapsan los eventos
      const seedRows = document.querySelectorAll(`.seeds-row[data-tournament-id="${tournamentId}"]`);
      seedRows.forEach(seedRow => {
        seedRow.classList.add('hidden');
        
        // Actualizar el estado de los botones de toggle
        const eventId = seedRow.getAttribute('data-event-id');
        const button = document.getElementById(`toggleSeedsButton-${eventId}`);
        if (button) {
          button.textContent = 'Ver Seeds';
          button.setAttribute('data-showing', 'false');
        }
      });
    }
  });
}

// Función para mostrar/ocultar seeds de un evento
window.toggleSeeds = function(tournamentId, eventId) {
  const seedsRow = document.getElementById(`seedsRow-${tournamentId}-${eventId}`);
  const button = document.getElementById(`toggleSeedsButton-${eventId}`);
  
  if (seedsRow.classList.contains('hidden')) {
    seedsRow.classList.remove('hidden');
    button.textContent = 'Ocultar Seeds';
    button.setAttribute('data-showing', 'true');
  } else {
    seedsRow.classList.add('hidden');
    button.textContent = 'Ver Seeds';
    button.setAttribute('data-showing', 'false');
  }
}
