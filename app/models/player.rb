class Player < ApplicationRecord
  has_many :event_seeds, dependent: :destroy
  has_many :events, through: :event_seeds
  has_many :tournaments, through: :events
  
  validates :name, presence: true
  validates :entrant_name, presence: true
  validates :user_id, presence: true, uniqueness: true
  validates :discriminator, presence: true

  # Validaciones para personajes de Smash
  validates :skin_1, inclusion: { in: 1..8 }, allow_nil: true
  validates :skin_2, inclusion: { in: 1..8 }, allow_nil: true
  validates :skin_3, inclusion: { in: 1..8 }, allow_nil: true

  # Scopes
  scope :search, ->(query) { 
    where("LOWER(entrant_name) LIKE LOWER(?) OR LOWER(name) LIKE LOWER(?)", "%#{query}%", "%#{query}%") if query.present?
  }

  # Constante con todos los personajes de Smash Ultimate
  SMASH_CHARACTERS = {
    'mario' => 'Mario',
    'donkey_kong' => 'Donkey Kong',
    'link' => 'Link',
    'samus' => 'Samus',
    'dark_samus' => 'Dark Samus',
    'yoshi' => 'Yoshi',
    'kirby' => 'Kirby',
    'fox' => 'Fox',
    'pikachu' => 'Pikachu',
    'luigi' => 'Luigi',
    'ness' => 'Ness',
    'captain_falcon' => 'Captain Falcon',
    'jigglypuff' => 'Jigglypuff',
    'peach' => 'Peach',
    'daisy' => 'Daisy',
    'bowser' => 'Bowser',
    'ice_climbers' => 'Ice Climbers',
    'sheik' => 'Sheik',
    'zelda' => 'Zelda',
    'dr_mario' => 'Dr. Mario',
    'pichu' => 'Pichu',
    'falco' => 'Falco',
    'marth' => 'Marth',
    'lucina' => 'Lucina',
    'young_link' => 'Young Link',
    'ganondorf' => 'Ganondorf',
    'mewtwo' => 'Mewtwo',
    'roy' => 'Roy',
    'chrom' => 'Chrom',
    'mr_game_and_watch' => 'Mr. Game & Watch',
    'meta_knight' => 'Meta Knight',
    'pit' => 'Pit',
    'dark_pit' => 'Dark Pit',
    'zero_suit_samus' => 'Zero Suit Samus',
    'wario' => 'Wario',
    'snake' => 'Snake',
    'ike' => 'Ike',
    'pokemon_trainer' => 'Pokémon Trainer',
    'diddy_kong' => 'Diddy Kong',
    'lucas' => 'Lucas',
    'sonic' => 'Sonic',
    'king_dedede' => 'King Dedede',
    'olimar' => 'Olimar',
    'lucario' => 'Lucario',
    'rob' => 'R.O.B.',
    'toon_link' => 'Toon Link',
    'wolf' => 'Wolf',
    'villager' => 'Villager',
    'mega_man' => 'Mega Man',
    'wii_fit_trainer' => 'Wii Fit Trainer',
    'rosalina_luma' => 'Rosalina & Luma',
    'little_mac' => 'Little Mac',
    'greninja' => 'Greninja',
    'palutena' => 'Palutena',
    'pac_man' => 'Pac-Man',
    'robin' => 'Robin',
    'shulk' => 'Shulk',
    'bowser_jr' => 'Bowser Jr.',
    'duck_hunt' => 'Duck Hunt',
    'ryu' => 'Ryu',
    'ken' => 'Ken',
    'cloud' => 'Cloud',
    'corrin' => 'Corrin',
    'bayonetta' => 'Bayonetta',
    'inkling' => 'Inkling',
    'ridley' => 'Ridley',
    'simon' => 'Simon',
    'richter' => 'Richter',
    'king_k_rool' => 'King K. Rool',
    'isabelle' => 'Isabelle',
    'incineroar' => 'Incineroar',
    'piranha_plant' => 'Piranha Plant',
    'joker' => 'Joker',
    'hero' => 'Hero',
    'banjo_kazooie' => 'Banjo & Kazooie',
    'terry' => 'Terry',
    'byleth' => 'Byleth',
    'min_min' => 'Min Min',
    'steve' => 'Steve',
    'sephiroth' => 'Sephiroth',
    'pyra_mythra' => 'Pyra/Mythra',
    'kazuya' => 'Kazuya',
    'sora' => 'Sora'
  }.freeze

  def smash_characters
    [
      character_1.present? ? { character: character_1, skin: skin_1 } : nil,
      character_2.present? ? { character: character_2, skin: skin_2 } : nil,
      character_3.present? ? { character: character_3, skin: skin_3 } : nil
    ].compact
  end

  def character_display_name(character_key)
    SMASH_CHARACTERS[character_key] || character_key&.humanize
  end

  # Método seguro para asignar gender_pronoun/gender_pronoum dependiendo de qué columna exista
  def assign_gender_pronoun(value)
    column_name = self.class.column_names.include?("gender_pronoun") ? "gender_pronoun" : "gender_pronoum"
    self[column_name] = value
  end
end
