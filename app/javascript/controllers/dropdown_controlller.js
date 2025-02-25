import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    console.log("Dropdown controller connected to", this.element)
    console.log("Element attributes:", this.element.attributes)
    if (this.hasMenuTarget) {
      console.log("Menu target found:", this.menuTarget)
    } else {
      console.error("No menu target found for dropdown controller. Searching DOM...")
      const menuElement = document.querySelector("[data-dropdown-target='menu']")
      if (menuElement) {
        this.menuTarget = menuElement
        console.log("Menu target found after manual search:", this.menuTarget)
      } else {
        console.error("No menu target found in DOM")
      }
    }
  }

  disconnect() {
    console.log("Dropdown controller disconnected from", this.element)
  }

  toggle() {
    console.log("Toggle clicked on", this.element)
    if (this.hasMenuTarget) {
      console.log("Menu target exists, current classList:", this.menuTarget.classList)
      this.menuTarget.classList.toggle("hidden")
      console.log("Menu toggled, new classList:", this.menuTarget.classList)
    } else {
      console.error("No menu target found for dropdown controller during toggle")
    }
  }
}