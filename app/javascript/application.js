// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "./controllers"
import "./seeds_functions"

//console.log("Stimulus application loaded:", window.Stimulus)

// Configure Turbo para evitar preload warnings innecesarios
import { Turbo } from "@hotwired/turbo-rails"

// Configurar Turbo para un comportamiento más eficiente
document.addEventListener("DOMContentLoaded", function() {
  // Reducir el uso agresivo de preload para evitar warnings
  if (typeof Turbo !== 'undefined') {
    // Configurar opciones de Turbo para desarrollo
    Turbo.session.cache.exemptFromCache = [
      'text/html'
    ]
  }
})
