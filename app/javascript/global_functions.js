// Global functions and variables for Smash Seeding Chile
// This file prevents redeclaration errors when navigating with Turbo

console.log("🚀 Cargando global_functions.js...");

// Ensure we only declare these once
if (typeof window.SmashSeeding === 'undefined') {
  window.SmashSeeding = {};
  console.log("✅ window.SmashSeeding inicializado");
}

// Character names mapping - only declare once
if (typeof window.SmashSeeding.characterNames === 'undefined') {
  window.SmashSeeding.characterNames = {
    'mario': 'Mario',
    'donkey_kong': 'Donkey Kong', 
    'link': 'Link',
    'samus': 'Samus',
    'dark_samus': 'Dark Samus',
    'yoshi': 'Yoshi',
    'kirby': 'Kirby',
    'fox': 'Fox',
    'pikachu': 'Pikachu',
    'luigi': 'Luigi',
    'ness': 'Ness',
    'captain_falcon': 'Captain Falcon',
    'jigglypuff': 'Jigglypuff',
    'peach': 'Peach',
    'daisy': 'Daisy',
    'bowser': 'Bowser',
    'ice_climbers': 'Ice Climbers',
    'sheik': 'Sheik',
    'zelda': 'Zelda',
    'dr_mario': 'Dr. Mario',
    'pichu': 'Pichu',
    'falco': 'Falco',
    'marth': 'Marth',
    'lucina': 'Lucina',
    'young_link': 'Young Link',
    'ganondorf': 'Ganondorf',
    'mewtwo': 'Mewtwo',
    'roy': 'Roy',
    'chrom': 'Chrom',
    'mr_game_and_watch': 'Mr. Game & Watch',
    'meta_knight': 'Meta Knight',
    'pit': 'Pit',
    'dark_pit': 'Dark Pit',
    'zero_suit_samus': 'Zero Suit Samus',
    'wario': 'Wario',
    'snake': 'Snake',
    'ike': 'Ike',
    'pokemon_trainer': 'Pokémon Trainer',
    'diddy_kong': 'Diddy Kong',
    'lucas': 'Lucas',
    'sonic': 'Sonic',
    'king_dedede': 'King Dedede',
    'olimar': 'Olimar',
    'lucario': 'Lucario',
    'rob': 'R.O.B.',
    'toon_link': 'Toon Link',
    'wolf': 'Wolf',
    'villager': 'Villager',
    'mega_man': 'Mega Man',
    'wii_fit_trainer': 'Wii Fit Trainer',
    'rosalina_luma': 'Rosalina & Luma',
    'little_mac': 'Little Mac',
    'greninja': 'Greninja',
    'palutena': 'Palutena',
    'pac_man': 'Pac-Man',
    'robin': 'Robin',
    'shulk': 'Shulk',
    'bowser_jr': 'Bowser Jr.',
    'duck_hunt': 'Duck Hunt',
    'ryu': 'Ryu',
    'ken': 'Ken',
    'cloud': 'Cloud',
    'corrin': 'Corrin',
    'bayonetta': 'Bayonetta',
    'inkling': 'Inkling',
    'ridley': 'Ridley',
    'simon': 'Simon',
    'richter': 'Richter',
    'king_k_rool': 'King K. Rool',
    'isabelle': 'Isabelle',
    'incineroar': 'Incineroar',
    'piranha_plant': 'Piranha Plant',
    'joker': 'Joker',
    'hero': 'Hero',
    'banjo_kazooie': 'Banjo & Kazooie',
    'terry': 'Terry',
    'byleth': 'Byleth',
    'min_min': 'Min Min',
    'steve': 'Steve',
    'sephiroth': 'Sephiroth',
    'pyra_mythra': 'Pyra/Mythra',
    'kazuya': 'Kazuya',
    'sora': 'Sora'
  };
}

// Mobile menu state - only declare once
if (typeof window.SmashSeeding.mobileMenuOpen === 'undefined') {
  window.SmashSeeding.mobileMenuOpen = false;
}

// Global functions for mobile menu
window.SmashSeeding.toggleMobileMenu = function() {
  const mobileMenu = document.getElementById('mobile-menu');
  const menuButton = document.querySelector('.mobile-menu-button');
  const menuIcon = menuButton?.querySelector('.menu-icon');
  
  if (!mobileMenu || !menuButton || !menuIcon) return;
  
  window.SmashSeeding.mobileMenuOpen = !window.SmashSeeding.mobileMenuOpen;
  
  if (window.SmashSeeding.mobileMenuOpen) {
    // Abrir menú
    mobileMenu.classList.remove('hidden');
    menuButton.classList.add('bg-slate-800');
    menuIcon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />';
  } else {
    // Cerrar menú
    mobileMenu.classList.add('hidden');
    menuButton.classList.remove('bg-slate-800');
    menuIcon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />';
  }
};

window.SmashSeeding.closeMobileMenu = function() {
  const mobileMenu = document.getElementById('mobile-menu');
  const menuButton = document.querySelector('.mobile-menu-button');
  const menuIcon = menuButton?.querySelector('.menu-icon');
  
  if (!mobileMenu || !menuButton || !menuIcon) return;
  
  window.SmashSeeding.mobileMenuOpen = false;
  mobileMenu.classList.add('hidden');
  menuButton.classList.remove('bg-slate-800');
  menuIcon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />';
};

// Character functions
window.SmashSeeding.updateCharacterPreview = function(slot) {
  const characterSelect = document.getElementById(`character_${slot}`);
  const skinSelect = document.getElementById(`skin_${slot}`);
  const previewDiv = document.getElementById(`character_${slot}_preview`);
  const iconDiv = document.getElementById(`character_${slot}_icon`);
  const nameP = document.getElementById(`character_${slot}_name`);
  const skinTextP = document.getElementById(`character_${slot}_skin_text`);
  const skinsGallery = document.getElementById(`skins_gallery_${slot}`);
  
  if (!characterSelect || !skinSelect || !previewDiv || !iconDiv || !nameP || !skinTextP || !skinsGallery) {
    return;
  }
  
  const character = characterSelect.value;
  const skin = skinSelect.value || 1;
  
  if (character) {
    // Mostrar vista previa
    previewDiv.classList.remove('hidden');
    
    // Actualizar icono
    const iconPath = `/assets/smash/characters/${character}_${skin}.png`;
    iconDiv.innerHTML = `<img src="${iconPath}" alt="${window.SmashSeeding.characterNames[character]} Skin ${skin}" 
                         class="w-12 h-12 border border-slate-700 rounded-md bg-slate-800 shadow-sm"
                         style="filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.3));"
                         onerror="this.onerror=null; this.src='data:image/svg+xml,%3Csvg xmlns=\\'http://www.w3.org/2000/svg\\' width=\\'48\\' height=\\'48\\' viewBox=\\'0 0 48 48\\'%3E%3Crect width=\\'48\\' height=\\'48\\' fill=\\'%2364748b\\'/%3E%3Ctext x=\\'24\\' y=\\'30\\' text-anchor=\\'middle\\' fill=\\'%23f1f5f9\\' font-size=\\'16\\' font-weight=\\'bold\\'%3E${character.charAt(0).toUpperCase()}%3C/text%3E%3C/svg%3E';">`;
    
    // Actualizar nombre y skin
    nameP.textContent = window.SmashSeeding.characterNames[character] || character.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
    skinTextP.textContent = `Skin ${skin}`;
    
    // Mostrar galería de skins
    skinsGallery.classList.remove('hidden');
    window.SmashSeeding.updateSkinsGallery(slot, character);
  } else {
    // Ocultar vista previa
    previewDiv.classList.add('hidden');
    skinsGallery.classList.add('hidden');
  }
};

window.SmashSeeding.updateSkinsGallery = function(slot, character) {
  const skinsGallery = document.getElementById(`skins_gallery_${slot}`);
  const skinButtons = skinsGallery?.querySelectorAll('.skin-selector');
  const currentSkin = document.getElementById(`skin_${slot}`)?.value || 1;
  
  if (!skinButtons) return;
  
  skinButtons.forEach((button, index) => {
    const skinNum = index + 1;
    const iconDiv = button.querySelector('div');
    
    if (!iconDiv) return;
    
    // Actualizar icono de la skin
    const iconPath = `/assets/smash/characters/${character}_${skinNum}.png`;
    iconDiv.innerHTML = `<img src="${iconPath}" alt="${window.SmashSeeding.characterNames[character]} Skin ${skinNum}" 
                         class="w-full h-full object-cover rounded"
                         onerror="this.onerror=null; this.src='data:image/svg+xml,%3Csvg xmlns=\\'http://www.w3.org/2000/svg\\' width=\\'24\\' height=\\'24\\' viewBox=\\'0 0 24 24\\'%3E%3Crect width=\\'24\\' height=\\'24\\' fill=\\'%2364748b\\'/%3E%3Ctext x=\\'12\\' y=\\'15\\' text-anchor=\\'middle\\' fill=\\'%23f1f5f9\\' font-size=\\'10\\' font-weight=\\'bold\\'%3E${skinNum}%3C/text%3E%3C/svg%3E';">`;
    
    // Resaltar skin actual
    if (skinNum == currentSkin) {
      button.classList.remove('border-transparent');
      if (slot == 1) button.classList.add('border-red-400');
      else if (slot == 2) button.classList.add('border-blue-400');
      else button.classList.add('border-green-400');
    } else {
      button.classList.add('border-transparent');
      button.classList.remove('border-red-400', 'border-blue-400', 'border-green-400');
    }
  });
};

window.SmashSeeding.selectSkin = function(slot, skinNum) {
  const skinSelect = document.getElementById(`skin_${slot}`);
  if (skinSelect) {
    skinSelect.value = skinNum;
    window.SmashSeeding.updateCharacterPreview(slot);
  }
};

// Initialize event listeners only once
if (!window.SmashSeeding.initialized) {
  document.addEventListener('DOMContentLoaded', function() {
    // Cerrar menú cuando se hace clic en los enlaces
    const mobileMenuLinks = document.querySelectorAll('#mobile-menu a');
    mobileMenuLinks.forEach(link => {
      link.addEventListener('click', window.SmashSeeding.closeMobileMenu);
    });
    
    // Cerrar menú al hacer clic fuera de él
    document.addEventListener('click', function(event) {
      const mobileMenu = document.getElementById('mobile-menu');
      const menuButton = document.querySelector('.mobile-menu-button');
      
      if (window.SmashSeeding.mobileMenuOpen && mobileMenu && menuButton && 
          !mobileMenu.contains(event.target) && !menuButton.contains(event.target)) {
        window.SmashSeeding.closeMobileMenu();
      }
    });
  });
  
  // Cerrar menú en navegación con Turbo
  document.addEventListener('turbo:visit', window.SmashSeeding.closeMobileMenu);
  
  window.SmashSeeding.initialized = true;
}

// Export for global access
window.toggleMobileMenu = window.SmashSeeding.toggleMobileMenu;
window.updateCharacterPreview = window.SmashSeeding.updateCharacterPreview;
window.selectSkin = window.SmashSeeding.selectSkin;

// Log final para confirmar que todo se cargó
console.log("🎉 global_functions.js cargado completamente. window.SmashSeeding disponible:", typeof window.SmashSeeding); 