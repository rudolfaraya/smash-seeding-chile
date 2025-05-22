class Player < ApplicationRecord
  has_many :event_seeds, dependent: :destroy
  has_many :events, through: :event_seeds
  has_many :tournaments, through: :events
  
  # Método seguro para asignar gender_pronoun/gender_pronoum dependiendo de qué columna exista
  def assign_gender_pronoun(value)
    column_name = self.class.column_names.include?("gender_pronoun") ? "gender_pronoun" : "gender_pronoum"
    self[column_name] = value
  end
end
