class AddPlacementToEventSeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :event_seeds, :placement, :integer, comment: "Posición final obtenida en el torneo (1er lugar, 2do lugar, etc.)"

    # Agregar índice para búsquedas eficientes por placement
    add_index :event_seeds, :placement
    add_index :event_seeds, [ :event_id, :placement ]
  end
end
