namespace :smash do
  desc "Synchronize Smash Ultimate data from Start.gg"
  task sync: :environment do
    SyncSmashData.new.call
  end
end
