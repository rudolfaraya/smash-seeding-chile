import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clearAllButton"]

  connect() {
    this.updateClearAllButtonVisibility()
    
    // Escuchar cambios en los inputs
    this.element.addEventListener('input', () => {
      this.updateClearAllButtonVisibility()
    })
    
    // Escuchar cambios en los selects
    this.element.addEventListener('change', () => {
      this.updateClearAllButtonVisibility()
    })
  }

  clearAllFilters(event) {
    event.preventDefault()
    
    // Resetear visualmente todos los campos del formulario
    this.resetFormFields()
    
    // Navegar a la URL sin filtros
    window.location.href = this.clearAllButtonTarget.href
  }

  resetFormFields() {
    // Resetear campo de búsqueda
    const searchInput = this.element.querySelector('input[name="query"]')
    if (searchInput) {
      searchInput.value = ''
    }
    
    // Resetear todos los selects a sus valores por defecto
    const selects = this.element.querySelectorAll('select')
    selects.forEach(select => {
      if (select.name === 'sort') {
        select.value = 'newest' // Valor por defecto para ordenamiento
      } else {
        select.value = '' // Valor vacío para otros filtros
      }
    })
    
    // Resetear campos de fecha
    const dateInputs = this.element.querySelectorAll('input[type="date"]')
    dateInputs.forEach(dateInput => {
      dateInput.value = ''
    })
    
    // Actualizar visibilidad del botón
    this.updateClearAllButtonVisibility()
  }

  updateClearAllButtonVisibility() {
    const hasFilters = this.hasAnyFilters()
    
    if (this.hasClearAllButtonTarget) {
      if (hasFilters) {
        this.clearAllButtonTarget.classList.remove('hidden')
      } else {
        this.clearAllButtonTarget.classList.add('hidden')
      }
    }
  }

  hasAnyFilters() {
    // Verificar búsqueda
    const searchInput = this.element.querySelector('input[name="query"]')
    if (searchInput && searchInput.value.trim() !== '') {
      return true
    }
    
    // Verificar filtros de select
    const selects = this.element.querySelectorAll('select')
    for (const select of selects) {
      // Para el ordenamiento, solo considerar como filtro si no es el valor por defecto
      if (select.name === 'sort') {
        if (select.value !== '' && select.value !== 'newest') {
          return true
        }
      } else {
        if (select.value !== '') {
          return true
        }
      }
    }
    
    // Verificar filtros de fecha
    const dateInputs = this.element.querySelectorAll('input[type="date"]')
    for (const dateInput of dateInputs) {
      if (dateInput.value !== '') {
        return true
      }
    }
    
    return false
  }
} 