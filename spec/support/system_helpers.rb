module SystemHelpers
  # Esperar a que aparezca un elemento específico
  def wait_for_element(selector, timeout: 5)
    expect(page).to have_css(selector, wait: timeout)
  end

  # Esperar a que aparezca texto específico
  def wait_for_text(text, timeout: 5)
    expect(page).to have_content(text, wait: timeout)
  end

  # Esperar a que desaparezca un elemento
  def wait_for_element_to_disappear(selector, timeout: 5)
    expect(page).not_to have_css(selector, wait: timeout)
  end

  # Llenar un campo y esperar a que se apliquen los filtros
  def fill_in_and_wait(field, with:, wait: 2)
    fill_in field, with: with
    sleep wait # Esperar a que se apliquen los filtros automáticamente
  end

  # Seleccionar una opción y esperar
  def select_and_wait(value, from:, wait: 2)
    select value, from: from
    sleep wait # Esperar a que se apliquen los filtros automáticamente
  end

  # Verificar que un torneo específico esté visible
  def expect_tournament_visible(tournament_name)
    expect(page).to have_content(tournament_name)
  end

  # Verificar que un torneo específico no esté visible
  def expect_tournament_not_visible(tournament_name)
    expect(page).not_to have_content(tournament_name)
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end 