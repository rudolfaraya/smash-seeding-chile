class EventSeed < ApplicationRecord
  belongs_to :event
  belongs_to :player

  # Verificar si el jugador superó las expectativas
  def exceeded_expectations?
    placement.present? && seed_num.present? && placement < seed_num
  end

  # Verificar si el jugador cumplió las expectativas
  def met_expectations?
    placement.present? && seed_num.present? && placement == seed_num
  end

  # Verificar si el jugador no cumplió las expectativas
  def underperformed?
    placement.present? && seed_num.present? && placement > seed_num
  end

  # Calcular la diferencia entre seed y placement (positivo = mejor que esperado)
  def performance_difference
    return nil unless placement.present? && seed_num.present?
    seed_num - placement
  end

  # Obtener categoría de rendimiento
  def performance_category
    return "Sin datos" unless placement.present? && seed_num.present?

    diff = performance_difference
    case
    when diff > 5 then "Excelente (+6 o más)"
    when diff > 2 then "Muy bueno (+3 a +5)"
    when diff > 0 then "Bueno (+1 a +2)"
    when diff == 0 then "Cumplió expectativas"
    when diff > -3 then "Bajo (-1 a -2)"
    when diff > -6 then "Muy bajo (-3 a -5)"
    else "Decepcionante (-6 o menos)"
    end
  end

  # Calcular porcentaje de mejora/empeoramiento
  def performance_percentage
    return nil unless placement.present? && seed_num.present?

    diff = performance_difference.to_f
    return 0.0 if diff == 0

    # Porcentaje de mejora/empeoramiento
    if diff > 0
      (diff / seed_num.to_f * 100).round(1)
    else
      (diff.abs / seed_num.to_f * 100).round(1) * -1
    end
  end

  # Verificar si tiene datos completos para análisis
  def complete_data?
    seed_num.present? && placement.present?
  end

  # Scope para analizar rendimientos
  scope :with_complete_data, -> { where.not(seed_num: nil, placement: nil) }
  scope :exceeded_expectations, -> { with_complete_data.where("placement < seed_num") }
  scope :met_expectations, -> { with_complete_data.where("placement = seed_num") }
  scope :underperformed, -> { with_complete_data.where("placement > seed_num") }

  # ✨ NUEVOS MÉTODOS PARA FACTOR POR RONDAS ✨

  # Calcula en qué ronda se esperaba que saliera el jugador basado en su seed
  def expected_round_out
    return nil unless seed_num.present?
    calculate_round_from_placement(seed_num)
  end

  # Calcula en qué ronda realmente salió el jugador basado en su placement
  def actual_round_out
    return nil unless placement.present?
    calculate_round_from_placement(placement)
  end

  # Factor de rendimiento basado en rondas (+/- rondas avanzadas)
  def round_performance_factor
    return nil unless expected_round_out && actual_round_out
    actual_round_out - expected_round_out
  end

  # Íconos y colores para mostrar el factor visualmente
  def performance_icon_data
    factor = round_performance_factor
    return { icon: "—", color: "text-gray-500 text-base", title: "Sin datos de placement" } if factor.nil?

    case
    when factor > 0
      {
        icon: "↗ +#{factor}",
        color: "text-green-400 font-bold text-xl",
        title: "Avanzó #{factor} ronda#{'s' if factor > 1} más de lo esperado"
      }
    when factor < 0
      {
        icon: "↘ #{factor}",
        color: "text-red-400 font-bold text-xl",
        title: "Salió #{factor.abs} ronda#{'s' if factor.abs > 1} antes de lo esperado"
      }
    else
      {
        icon: "● 0",
        color: "text-blue-400 font-bold text-lg",
        title: "Cumplió exactamente sus expectativas"
      }
    end
  end

  # Texto descriptivo del rendimiento
  def performance_description
    factor = round_performance_factor
    return "Sin datos" if factor.nil?

    case
    when factor > 2 then "Rendimiento excepcional"
    when factor > 0 then "Superó expectativas"
    when factor == 0 then "Cumplió expectativas"
    when factor > -2 then "Bajo expectativas"
    else "Muy bajo rendimiento"
    end
  end

  private

  # Mapea un placement a la ronda en que se elimina en doble eliminación
  def calculate_round_from_placement(placement_position)
    return nil if placement_position.nil? || placement_position <= 0

    # En doble eliminación, los placements siguen un patrón específico:
    # 1° = Ganador (no se elimina)
    # 2° = Perdió en Grand Finals
    # 3° = Perdió en Winners/Losers Finals
    # 4° = Perdió en Winners/Losers Semis
    # 5°-5° = Perdió en Winners/Losers Quarters
    # 7°-7° = Perdió en ronda anterior
    # etc.

    case placement_position
    when 1
      # Ganador - asignamos la ronda más alta
      10  # Valor alto para representar que no se eliminó
    when 2
      9   # Grand Finals
    when 3
      8   # Winners/Losers Finals
    when 4
      7   # Winners/Losers Semis
    when 5..6
      6   # Quarters
    when 7..8
      5   # Round antes de quarters
    when 9..12
      4   #
    when 13..16
      3
    when 17..24
      2
    when 25..32
      1
    else
      # Para brackets más grandes, usar logaritmo
      # Cada "duplicación" de placements = una ronda anterior
      Math.log2(placement_position).floor
    end
  end
end
