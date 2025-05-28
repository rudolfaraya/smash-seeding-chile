import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "mainImage", 
    "skinOption", 
    "characterName", 
    "skinName", 
    "skinDescription",
    "glowEffect",
    "selectionRing",
    "skinDetails"
  ]
  
  static values = {
    character: String,
    selectedSkin: { type: Number, default: 0 }
  }
  
  connect() {
    console.log("🎮 Character Skin Selector conectado")
    this.setupSkinDescriptions()
    this.updateGlowEffect()
  }
  
  selectSkin(event) {
    const skinIndex = parseInt(event.currentTarget.dataset.skinIndex)
    
    if (skinIndex === this.selectedSkinValue) return
    
    // Animación de salida de la skin actual
    this.animateOut(() => {
      // Cambiar la skin
      this.changeSkin(skinIndex)
      
      // Animación de entrada de la nueva skin
      this.animateIn()
    })
    
    // Actualizar selección visual
    this.updateSelection(skinIndex)
    
    // Actualizar valor
    this.selectedSkinValue = skinIndex
  }
  
  changeSkin(skinIndex) {
    const characterName = this.characterValue
    
    // Determinar la ruta según la nueva estructura
    let newImagePath;
    
    // Verificar si es un personaje Mii (sin skins)
    const charactersWithoutSkins = ['mii_brawler', 'mii_swordfighter', 'mii_gunner'];
    if (charactersWithoutSkins.includes(characterName)) {
      // Para Mii: usar solo el nombre del personaje
      let miiName;
      switch(characterName) {
        case 'mii_brawler': miiName = 'brawler'; break;
        case 'mii_gunner': miiName = 'gunner'; break;
        case 'mii_swordfighter': miiName = 'swordfighter'; break;
        default: miiName = characterName;
      }
      newImagePath = `/assets/smash/character_individual_skins/${characterName}/${miiName}.png`;
    } else {
      // Para personajes normales: usar skin del 1 al 8
      const skinNumber = skinIndex + 1;
      newImagePath = `/assets/smash/character_individual_skins/${characterName}/${skinNumber}.png`;
    }
    
    // Cambiar imagen principal
    this.mainImageTarget.src = newImagePath
    this.mainImageTarget.alt = `${this.characterNameTarget.textContent} - Skin ${skinIndex + 1}`
    
    // Actualizar información
    this.updateSkinInfo(skinIndex)
    
    // Actualizar efectos
    this.updateGlowEffect(skinIndex)
  }
  
  updateSelection(skinIndex) {
    // Remover selección anterior
    this.skinOptionTargets.forEach(option => {
      option.classList.remove('active')
      option.querySelector('.selection-indicator').classList.remove('active')
    })
    
    // Agregar selección nueva
    const selectedOption = this.skinOptionTargets[skinIndex]
    selectedOption.classList.add('active')
    selectedOption.querySelector('.selection-indicator').classList.add('active')
  }
  
  updateSkinInfo(skinIndex) {
    const skinDescriptions = this.getSkinDescriptions()
    const characterName = this.characterValue
    
    this.skinNameTarget.textContent = skinDescriptions[skinIndex] || `Skin ${skinIndex + 1}`
    this.skinDescriptionTarget.textContent = skinDescriptions[skinIndex] || `Skin ${skinIndex + 1}`
  }
  
  updateGlowEffect(skinIndex = 0) {
    const colors = this.getSkinColors()
    const color = colors[skinIndex] || colors[0]
    
    this.glowEffectTarget.style.boxShadow = `0 0 30px ${color}, 0 0 60px ${color}40`
    this.selectionRingTarget.style.borderColor = color
  }
  
  animateOut(callback) {
    this.mainImageTarget.style.transform = 'scale(0.8) rotateY(90deg)'
    this.mainImageTarget.style.opacity = '0.3'
    
    setTimeout(() => {
      callback()
    }, 150)
  }
  
  animateIn() {
    setTimeout(() => {
      this.mainImageTarget.style.transform = 'scale(1.1) rotateY(-10deg)'
      this.mainImageTarget.style.opacity = '1'
      
      setTimeout(() => {
        this.mainImageTarget.style.transform = 'scale(1) rotateY(0deg)'
      }, 200)
    }, 50)
  }
  
  setupSkinDescriptions() {
    // Configurar descripciones específicas por personaje
    this.skinDescriptions = this.getSkinDescriptions()
  }
  
  getSkinDescriptions() {
    const descriptions = {
      'mario': [
        'Clásico', 'Fuego', 'Wario', 'Foreman', 'Americano', 'Golf', 'Constructor', 'Boda'
      ],
      'luigi': [
        'Clásico', 'Blanco', 'Azul', 'Rosa', 'Verde Oscuro', 'Naranja', 'Púrpura', 'Fuego'
      ],
      'pikachu': [
        'Clásico', 'Rojo', 'Verde', 'Azul', 'Amarillo', 'Libre', 'Banda Roja', 'Banda Azul'
      ],
      'link': [
        'Clásico', 'Rojo', 'Azul', 'Púrpura', 'Goron', 'Zora', 'Oscuro', 'Fierce Deity'
      ]
    }
    
    return descriptions[this.characterValue] || [
      'Skin 1', 'Skin 2', 'Skin 3', 'Skin 4', 'Skin 5', 'Skin 6', 'Skin 7', 'Skin 8'
    ]
  }
  
  getSkinColors() {
    const colors = {
      'mario': [
        '#FF0000', '#FF4500', '#FFD700', '#8B4513', '#FF1493', '#32CD32', '#FF8C00', '#FFFFFF'
      ],
      'luigi': [
        '#00FF00', '#FFFFFF', '#0000FF', '#FF69B4', '#006400', '#FF4500', '#8A2BE2', '#FF0000'
      ],
      'pikachu': [
        '#FFFF00', '#FF0000', '#00FF00', '#0000FF', '#FFD700', '#FF69B4', '#FF4500', '#00BFFF'
      ],
      'link': [
        '#00FF00', '#FF0000', '#0000FF', '#8A2BE2', '#8B4513', '#00CED1', '#2F4F4F', '#FFD700'
      ]
    }
    
    return colors[this.characterValue] || [
      '#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF', '#00FFFF', '#FFA500', '#800080'
    ]
  }
} 