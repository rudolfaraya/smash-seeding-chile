class FixGenderPronounColumnInPlayers < ActiveRecord::Migration[7.2]
  def change
    rename_column :players, :gender_pronoum, :gender_pronoun
  end
end
