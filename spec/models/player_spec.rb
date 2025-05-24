require 'rails_helper'

RSpec.describe Player, type: :model do
  describe 'validations' do
    subject { build(:player) }

    it { should validate_presence_of(:entrant_name) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:user_id) }
    it { should validate_uniqueness_of(:user_id) }
    it { should validate_presence_of(:discriminator) }
  end

  describe 'associations' do
    it { should have_many(:event_seeds).dependent(:destroy) }
    it { should have_many(:events).through(:event_seeds) }
    it { should have_many(:tournaments).through(:events) }
  end

  describe 'scopes' do
    let!(:player_with_prefix) { create(:player, :with_chilean_tag) }
    let!(:player_with_region) { create(:player, :with_region_tag) }
    let!(:regular_player) { create(:player) }

    describe '.search' do
      let!(:player1) { create(:player, entrant_name: 'TestPlayer') }
      let!(:player2) { create(:player, entrant_name: 'AnotherGamer') }

      it 'finds players by entrant_name' do
        results = Player.search('TestPlayer')
        expect(results).to include(player1)
        expect(results).not_to include(player2)
      end

      it 'is case insensitive' do
        results = Player.search('testplayer')
        expect(results).to include(player1)
      end

      it 'finds partial matches' do
        results = Player.search('Test')
        expect(results).to include(player1)
      end
    end
  end

  describe 'instance methods' do
    describe '#name' do
      let(:player) { build(:player, name: 'John Doe') }

      it 'returns the player name' do
        expect(player.name).to eq('John Doe')
      end
    end

    describe '#entrant_name' do
      let(:player) { build(:player, entrant_name: 'TestPlayer') }

      it 'returns the entrant name' do
        expect(player.entrant_name).to eq('TestPlayer')
      end
    end
  end

  describe 'class methods' do
    describe '.all' do
      let!(:player1) { create(:player) }
      let!(:player2) { create(:player) }

      it 'returns all players' do
        expect(Player.all).to include(player1, player2)
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:player)).to be_valid
    end

    it 'creates player with Chilean tag' do
      player = create(:player, :with_chilean_tag)
      expect(player.entrant_name).to start_with('CL|')
    end

    it 'creates player with regional tag' do
      player = create(:player, :with_region_tag)
      expect(player.entrant_name).to match(/^(SCL|VLP|ANF|TMC|IQQ)\|/)
    end
  end
end 