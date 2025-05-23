# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_05_24_222228) do
  create_table "event_seeds", force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "player_id", null: false
    t.integer "seed_num"
    t.string "character_stock_icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_seeds_on_event_id"
    t.index ["player_id"], name: "index_event_seeds_on_player_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "tournament_id", null: false
    t.string "name"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "seeds_last_synced_at"
    t.integer "start_gg_event_id"
    t.index ["tournament_id"], name: "index_events_on_tournament_id"
  end

  create_table "players", force: :cascade do |t|
    t.string "entrant_name"
    t.integer "user_id"
    t.string "name"
    t.string "discriminator"
    t.text "bio"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "gender_pronoun"
    t.string "birthday"
    t.string "twitter_handle"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "character_1"
    t.integer "skin_1", default: 1
    t.string "character_2"
    t.integer "skin_2", default: 1
    t.string "character_3"
    t.integer "skin_3", default: 1
    t.index ["character_1"], name: "index_players_on_character_1"
    t.index ["character_2"], name: "index_players_on_character_2"
    t.index ["character_3"], name: "index_players_on_character_3"
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.datetime "start_at"
    t.datetime "end_at"
    t.string "venue_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "city"
    t.string "region"
    t.string "start_gg_url"
    t.index ["city"], name: "index_tournaments_on_city"
    t.index ["region"], name: "index_tournaments_on_region"
  end

  add_foreign_key "event_seeds", "events"
  add_foreign_key "event_seeds", "players"
  add_foreign_key "events", "tournaments"
end
