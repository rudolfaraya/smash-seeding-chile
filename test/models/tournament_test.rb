require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  # No cargar fixtures automáticamente para evitar problemas
  self.use_transactional_tests = true
  # test "the truth" do
  #   assert true
  # end

  test "should mark tournament as online when venue_address is Chile" do
    tournament = Tournament.new(
      name: "Test Tournament",
      slug: "test-tournament",
      venue_address: "Chile",
      start_at: 1.day.from_now
    )

    tournament.save!

    assert tournament.online?, "Tournament should be marked as online"
    assert_equal "Online", tournament.region
    assert_nil tournament.city
  end

  test "should not mark tournament as online when venue_address is not Chile" do
    tournament = Tournament.new(
      name: "Test Tournament",
      slug: "test-tournament-2",
      venue_address: "Santiago, Chile",
      start_at: 1.day.from_now
    )

    tournament.save!

    # Debería procesarse normalmente por el parser de ubicaciones
    assert_not tournament.online?, "Tournament should not be automatically marked as online"
  end

  test "should mark existing tournament as online when updating venue_address to Chile" do
    tournament = Tournament.create!(
      name: "Test Tournament",
      slug: "test-tournament-3",
      venue_address: "Santiago, Chile",
      start_at: 1.day.from_now
    )

    # Inicialmente no debería ser online
    assert_not tournament.online?

    # Cambiar venue_address a "Chile"
    tournament.update!(venue_address: "Chile")

    assert tournament.online?, "Tournament should be marked as online after updating venue_address"
    assert_equal "Online", tournament.region
    assert_nil tournament.city
  end

  test "callback should run before location parser" do
    tournament = Tournament.new(
      name: "Test Tournament",
      slug: "test-tournament-4",
      venue_address: "Chile",
      start_at: 1.day.from_now
    )

    # El callback mark_chile_as_online debería ejecutarse y marcar como online
    # antes de que el parser de ubicaciones pueda procesarlo
    tournament.save!

    assert_equal "Online", tournament.region
    assert_nil tournament.city
    assert tournament.online?
  end
end
