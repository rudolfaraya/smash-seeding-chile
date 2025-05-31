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

    # Patrón de brackets de eliminación doble real:
    # 1,2,3,4,5,5,7,7,9,9,9,9,13,13,13,13,17,17,17,17,17,17,17,17,25,25,25,25,25,25,25,25,
    # 33,33,33,33,33,33,33,33,33,33,33,33,33,33,33,33, (16 veces 33)
    # 49,49,49,49,49,49,49,49,49,49,49,49,49,49,49,49, (16 veces 49)
    # 65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65, (32 veces 65)
    # 97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97, (32 veces 97)
    # 129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,
    # 129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129,129 (64 veces 129)

    case placement_position
    when 1
      10  # Ganador (no se elimina)
    when 2
      9   # Grand Finals (perdió en final)
    when 3
      8   # Winners/Losers Finals
    when 4
      7   # Winners/Losers Semis
    when 5..6
      6   # Quarters (2 personas)
    when 7..8
      5   # Round of 16 (2 personas)
    when 9..12
      4   # Round of 24 (4 personas)
    when 13..16
      3   # Round of 32 (4 personas)
    when 17..24
      2   # Round of 48 (8 personas)
    when 25..32
      1   # Round of 64 (8 personas)
    when 33..48
      0   # Round of 96 (16 personas - 33 a 48)
    when 49..64
      -1  # Round of 128 (16 personas - 49 a 64)
    when 65..96
      -2  # Round of 192 (32 personas - 65 a 96)
    when 97..128
      -3  # Round of 256 (32 personas - 97 a 128)
    when 129..192
      -4  # Round of 384 (64 personas - 129 a 192)
    when 193..256
      -5  # Round of 512 (64 personas - 193 a 256)
    when 257..384
      -6  # Round of 768 (128 personas - 257 a 384)
    when 385..512
      -7  # Round of 1024 (128 personas - 385 a 512)
    else
      # Para brackets aún más grandes, usar fórmula logarítmica
      # Encuentra el próximo power-of-2 y calcula rondas hacia atrás
      next_power = (placement_position - 1).bit_length
      -(next_power - 8)  # Normalizado para que 256+ sea negativo
    end
  end
end
