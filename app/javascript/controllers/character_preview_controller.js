import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = []

  connect() {
    console.log("Character preview controller connected")
  }

  updateCharacter(event) {
    const characterNumber = event.target.dataset.characterNumber
    const selectedCharacter = event.target.value
    
    console.log(`Updating character ${characterNumber} to:`, selectedCharacter)
    
    const previewDiv = document.getElementById(`character_${characterNumber}_preview`)
    const iconDiv = document.getElementById(`character_${characterNumber}_icon`)
    const nameP = document.getElementById(`character_${characterNumber}_name`)
    const skinSelect = event.target.closest('.space-y-3').querySelector('.skin-select')
    
    if (selectedCharacter === '') {
      // Ocultar vista previa si no hay personaje seleccionado
      previewDiv.classList.add('hidden')
      // Resetear skin select
      skinSelect.value = ''
      return
    }
    
    // Obtener el nombre del personaje
    const characterNames = {
      'banjo_kazooie': 'Banjo & Kazooie',
      'bayonetta': 'Bayonetta',
      'bowser': 'Bowser',
      'bowser_jr': 'Bowser Jr.',
      'byleth': 'Byleth',
      'captain_falcon': 'Captain Falcon',
      'chrom': 'Chrom',
      'cloud': 'Cloud',
      'corrin': 'Corrin',
      'daisy': 'Daisy',
      'dark_pit': 'Dark Pit',
      'dark_samus': 'Dark Samus',
      'diddy_kong': 'Diddy Kong',
      'donkey_kong': 'Donkey Kong',
      'dr_mario': 'Dr. Mario',
      'duck_hunt': 'Duck Hunt',
      'falco': 'Falco',
      'fox': 'Fox',
      'ganondorf': 'Ganondorf',
      'greninja': 'Greninja',
      'hero': 'Hero',
      'ice_climbers': 'Ice Climbers',
      'ike': 'Ike',
      'incineroar': 'Incineroar',
      'inkling': 'Inkling',
      'isabelle': 'Isabelle',
      'jigglypuff': 'Jigglypuff',
      'joker': 'Joker',
      'kazuya': 'Kazuya',
      'ken': 'Ken',
      'king_dedede': 'King Dedede',
      'king_k_rool': 'King K. Rool',
      'kirby': 'Kirby',
      'link': 'Link',
      'little_mac': 'Little Mac',
      'lucario': 'Lucario',
      'lucas': 'Lucas',
      'lucina': 'Lucina',
      'luigi': 'Luigi',
      'mario': 'Mario',
      'marth': 'Marth',
      'mega_man': 'Mega Man',
      'meta_knight': 'Meta Knight',
      'mewtwo': 'Mewtwo',
      'mii_brawler': 'Mii Brawler',
      'mii_gunner': 'Mii Gunner',
      'mii_swordfighter': 'Mii Swordfighter',
      'min_min': 'Min Min',
      'mr_game_and_watch': 'Mr. Game & Watch',
      'ness': 'Ness',
      'olimar': 'Olimar',
      'pac_man': 'Pac-Man',
      'palutena': 'Palutena',
      'peach': 'Peach',
      'pichu': 'Pichu',
      'pikachu': 'Pikachu',
      'piranha_plant': 'Piranha Plant',
      'pit': 'Pit',
      'pokemon_trainer': 'Pokémon Trainer',
      'pyra_mythra': 'Pyra/Mythra',
      'richter': 'Richter',
      'ridley': 'Ridley',
      'rob': 'R.O.B.',
      'robin': 'Robin',
      'rosalina_luma': 'Rosalina & Luma',
      'roy': 'Roy',
      'ryu': 'Ryu',
      'samus': 'Samus',
      'sephiroth': 'Sephiroth',
      'sheik': 'Sheik',
      'shulk': 'Shulk',
      'simon': 'Simon',
      'snake': 'Snake',
      'sonic': 'Sonic',
      'sora': 'Sora',
      'steve': 'Steve',
      'terry': 'Terry',
      'toon_link': 'Toon Link',
      'villager': 'Villager',
      'wario': 'Wario',
      'wii_fit_trainer': 'Wii Fit Trainer',
      'wolf': 'Wolf',
      'yoshi': 'Yoshi',
      'young_link': 'Young Link',
      'zelda': 'Zelda',
      'zero_suit_samus': 'Zero Suit Samus'
    }
    
    const characterName = characterNames[selectedCharacter] || selectedCharacter.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
    
    // Actualizar nombre del personaje
    nameP.textContent = characterName
    
    // Obtener skin actual o defaultear a 1
    const currentSkin = skinSelect.value || '1'
    
    // Actualizar vista previa
    this.updateCharacterPreview(characterNumber, selectedCharacter, currentSkin)
    
    // Mostrar vista previa
    previewDiv.classList.remove('hidden')
  }

  updateSkin(event) {
    const characterNumber = event.target.dataset.characterNumber
    const selectedSkin = event.target.value
    
    console.log(`Updating skin for character ${characterNumber} to:`, selectedSkin)
    
    const characterSelect = event.target.closest('.space-y-3').querySelector('.character-select')
    const selectedCharacter = characterSelect.value
    const skinTextP = document.getElementById(`character_${characterNumber}_skin_text`)
    
    if (selectedCharacter === '' || selectedSkin === '') {
      return
    }
    
    // Actualizar texto del skin
    skinTextP.textContent = `Skin ${selectedSkin}`
    
    // Actualizar vista previa
    this.updateCharacterPreview(characterNumber, selectedCharacter, selectedSkin)
  }

  updateCharacterPreview(characterNumber, character, skin) {
    const iconDiv = document.getElementById(`character_${characterNumber}_icon`)
    
    if (!character || character === '') {
      iconDiv.innerHTML = ''
      return
    }
    
    // Crear imagen del personaje
    const imgSrc = `/assets/smash/characters/${character}_${skin || 1}.png`
    
    iconDiv.innerHTML = `
      <img src="${imgSrc}" 
           alt="${character}" 
           class="smash-character-icon border border-slate-700 rounded-md bg-slate-800 shadow-sm"
           width="64" 
           height="64" 
           style="filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3));"
           onerror="this.src='/assets/smash/characters/${character}_1.png'">
    `
  }
} 