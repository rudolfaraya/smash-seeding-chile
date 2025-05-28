// Funciones globales para manejar seeds sin controladores Stimulus múltiples

// Función para desktop
window.toggleDesktopSeeds = function(url, tournamentId, eventId) {
  console.log("Toggle desktop seeds para:", tournamentId, eventId, url)
  
  const seedRowId = `seedsRow-${tournamentId}-${eventId}`
  const existingRow = document.getElementById(seedRowId)
  
  if (existingRow) {
    // Si ya existe, alternar visibilidad
    const isHidden = existingRow.style.display === 'none' || existingRow.classList.contains('hidden')
    
    if (isHidden) {
      existingRow.classList.remove('hidden')
      existingRow.style.display = 'table-row'
      existingRow.classList.add('fade-in-down')
    } else {
      existingRow.classList.add('fade-out-up')
      setTimeout(() => {
        existingRow.classList.add('hidden')
        existingRow.style.display = 'none'
        existingRow.classList.remove('fade-out-up')
      }, 300)
    }
    return
  }
  
  // Crear nueva fila
  const eventRow = document.querySelector(`tr.event-row[data-tournament-id="${tournamentId}"][data-event-id="${eventId}"]`)
  if (!eventRow) {
    console.error("No se encontró la fila del evento")
    return
  }
  
  // Crear la fila para los seeds
  const newSeedRow = document.createElement('tr')
  newSeedRow.id = seedRowId
  newSeedRow.className = 'seeds-row border-b border-slate-600'
  newSeedRow.setAttribute('data-tournament-id', tournamentId)
  newSeedRow.setAttribute('data-event-id', eventId)
  
  // Crear celda para el contenido
  const cell = document.createElement('td')
  cell.setAttribute('colspan', '5')
  cell.className = 'py-2 px-6'
  
  // Crear div para el contenido de seeds
  const container = document.createElement('div')
  container.id = `event-seeds-${eventId}`
  container.className = 'pl-8 pr-8'
  
  // Mostrar indicador de carga
  container.innerHTML = `
    <div class="flex justify-center p-4">
      <div class="flex items-center">
        <svg class="animate-spin h-4 w-4 text-red-500 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span class="text-slate-300 text-xs">Cargando seeds...</span>
      </div>
    </div>
  `
  
  cell.appendChild(container)
  newSeedRow.appendChild(cell)
  eventRow.parentNode.insertBefore(newSeedRow, eventRow.nextSibling)
  
  // Mostrar la fila
  newSeedRow.classList.add('fade-in-down')
  
  // Cargar datos via AJAX
  fetch(url, {
    headers: {
      'Accept': 'text/html',
      'X-Requested-With': 'XMLHttpRequest'
    }
  })
  .then(response => response.text())
  .then(html => {
    container.innerHTML = html
  })
  .catch(error => {
    console.error("Error cargando seeds:", error)
    container.innerHTML = `
      <div class="p-4 bg-red-900/50 text-slate-200 rounded-lg border border-red-600 my-2">
        <div class="flex items-center">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-red-300 mr-2" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
          <span class="text-sm">Error al cargar los seeds. Por favor intenta de nuevo.</span>
        </div>
      </div>
    `
  })
}

// Función completamente rediseñada para móviles - crea contenido propio sin depender del HTML de desktop
window.toggleMobileSeeds = function(url, tournamentId, eventId) {
  console.log("Toggle mobile seeds para:", tournamentId, eventId, url)
  
  const seedContainerId = `mobile-seeds-${tournamentId}-${eventId}`
  const existingContainer = document.getElementById(seedContainerId)
  
  if (existingContainer) {
    // Si ya existe, alternar visibilidad
    if (existingContainer.style.display === 'none') {
      existingContainer.style.display = 'block'
    } else {
      existingContainer.style.display = 'none'
    }
    return
  }
  
  // Buscar el contenedor del evento
  const mobileEventsDiv = document.getElementById(`mobile-events-${tournamentId}`)
  if (!mobileEventsDiv) {
    console.error("No se encontró el contenedor de eventos móviles")
    return
  }
  
  // Buscar el div específico del evento
  const eventDivs = mobileEventsDiv.querySelectorAll('.py-2.border-b')
  let targetEventDiv = null
  
  eventDivs.forEach(div => {
    const eventButton = div.querySelector(`button[onclick*="toggleMobileSeeds"][onclick*="${eventId}"]`)
    if (eventButton) {
      targetEventDiv = div
    }
  })
  
  if (!targetEventDiv) {
    console.error("No se encontró el div del evento específico")
    return
  }
  
  // Crear contenedor completamente nuevo SIN restricciones
  const seedContainer = document.createElement('div')
  seedContainer.id = seedContainerId
  seedContainer.style.cssText = `
    margin: 12px 0;
    background: #334155;
    border-radius: 8px;
    border: 1px solid #475569;
    padding: 0;
    width: 100%;
    display: block;
    position: relative;
    z-index: 1;
    overflow: visible !important;
    height: auto !important;
    max-height: none !important;
  `
  
  const container = document.createElement('div')
  container.style.cssText = `
    padding: 8px;
    width: 100%;
    overflow: visible !important;
    height: auto !important;
    max-height: none !important;
    box-sizing: border-box;
  `
  
  // Mostrar indicador de carga
  container.innerHTML = `
    <div style="display: flex; justify-content: center; padding: 16px;">
      <div style="display: flex; align-items: center;">
        <div style="
          width: 16px; 
          height: 16px; 
          border: 2px solid #ef4444; 
          border-top: 2px solid transparent; 
          border-radius: 50%; 
          animation: spin 1s linear infinite;
          margin-right: 8px;
        "></div>
        <span style="color: #cbd5e1; font-size: 12px;">Cargando seeds...</span>
      </div>
    </div>
    <style>
      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }
    </style>
  `
  
  seedContainer.appendChild(container)
  targetEventDiv.parentNode.insertBefore(seedContainer, targetEventDiv.nextSibling)
  
  // Cargar datos via AJAX pero crear nuestro propio HTML móvil
  fetch(url, {
    headers: {
      'Accept': 'text/html',
      'X-Requested-With': 'XMLHttpRequest'
    }
  })
  .then(response => response.text())
  .then(html => {
    // Extraer datos de la tabla y crear versión móvil propia
    const tempDiv = document.createElement('div')
    tempDiv.innerHTML = html
    
    const table = tempDiv.querySelector('table')
    if (table) {
      createMobileSeedsView(container, table)
    } else {
      container.innerHTML = `
        <div style="padding: 16px; text-align: center; color: #cbd5e1; font-size: 12px;">
          No hay seeds disponibles para este evento.
        </div>
      `
    }
  })
  .catch(error => {
    console.error("Error cargando seeds:", error)
    container.innerHTML = `
      <div style="
        padding: 16px; 
        background: #7f1d1d; 
        color: #fecaca; 
        border-radius: 6px; 
        margin: 8px 0;
        font-size: 12px;
      ">
        Error al cargar los seeds. Por favor intenta de nuevo.
      </div>
    `
  })
}

// Función para crear una vista móvil completamente nueva
function createMobileSeedsView(container, table) {
  console.log("Creando vista móvil propia de seeds")
  
  const rows = table.querySelectorAll('tbody tr')
  
  let mobileHTML = `
    <div style="
      background: #1e293b;
      border-radius: 6px;
      padding: 8px;
      margin: 4px 0;
      border: 1px solid #ef4444;
    ">
      <h4 style="
        color: #f8fafc;
        font-size: 12px;
        font-weight: bold;
        margin: 0 0 8px 0;
        display: flex;
        align-items: center;
      ">
        <span style="
          width: 4px;
          height: 4px;
          background: #ef4444;
          border-radius: 50%;
          margin-right: 6px;
        "></span>
        Seeds del Evento
      </h4>
    </div>
  `
  
  rows.forEach((row, index) => {
    const cells = row.querySelectorAll('td')
    if (cells.length >= 4) {
      // Nueva estructura: [Seed, Equipo, Nombre, Personajes]
      const seedNumber = cells[0]?.textContent?.trim() || ''
      const equipoCell = cells[1] // Nueva columna de equipos
      const nombreCell = cells[2]
      const personajesCell = cells[3]
      
      // Extraer información de equipos
      let equiposHTML = ''
      if (equipoCell) {
        const equipoImgs = equipoCell.querySelectorAll('img')
        const equipoDivs = equipoCell.querySelectorAll('div.flex.items-center.justify-center')
        
        if (equipoImgs.length > 0 || equipoDivs.length > 0) {
          equiposHTML = '<div style="display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 4px;">'
          
          // Procesar imágenes de logos de equipos
          equipoImgs.forEach(img => {
            if (img.src && !img.src.includes('users-slash')) {
              equiposHTML += `<img src="${img.src}" style="width: 16px; height: 16px; border-radius: 2px;" alt="Team logo">`
            }
          })
          
          // Procesar cuadrados con siglas de equipos
          equipoDivs.forEach(div => {
            const siglaSpan = div.querySelector('span')
            if (siglaSpan && siglaSpan.textContent.trim()) {
              equiposHTML += `<div style="
                width: 16px;
                height: 16px;
                background: linear-gradient(135deg, #7c3aed, #a855f7);
                border-radius: 2px;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 8px;
                font-weight: bold;
                color: white;
              ">${siglaSpan.textContent.trim()}</div>`
            }
          })
          
          equiposHTML += '</div>'
        }
      }
      
      // Extraer personajes
      let personajesHTML = ''
      if (personajesCell) {
        const personajeImgs = personajesCell.querySelectorAll('img')
        if (personajeImgs.length > 0) {
          personajesHTML = '<div style="display: flex; gap: 2px; flex-wrap: wrap;">'
          personajeImgs.forEach(img => {
            if (img.src) {
              personajesHTML += `<img src="${img.src}" style="width: 20px; height: 20px; border-radius: 3px;" alt="${img.alt || 'Character'}">`
            }
          })
          personajesHTML += '</div>'
        }
      }
      
      // Extraer nombre
      const nombre = nombreCell?.textContent?.trim() || ''
      
      mobileHTML += `
        <div style="
          background: #334155;
          border-radius: 6px;
          padding: 8px;
          margin: 6px 0;
          border: 1px solid #475569;
        ">
          <div style="
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 6px;
          ">
            <div style="
              background: #ef4444;
              color: white;
              font-weight: bold;
              font-size: 12px;
              padding: 2px 6px;
              border-radius: 3px;
              min-width: 20px;
              text-align: center;
            ">${seedNumber}</div>
            ${equiposHTML}
          </div>
          
          <div style="
            color: #f8fafc;
            font-size: 11px;
            font-weight: 500;
            margin-bottom: 4px;
            word-break: break-word;
          ">${nombre}</div>
          
          ${personajesHTML}
        </div>
      `
    }
  })
  
  container.innerHTML = mobileHTML
} 