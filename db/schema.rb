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

ActiveRecord::Schema[7.2].define(version: 2025_02_20_134638) do
  create_table "event_seeds", force: :cascade do |t|
    t.integer "tournament_id", null: false
    t.integer "player_id", null: false
    t.integer "event_id", null: false
    t.string "event_name"
    t.integer "seed_num", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_event_seeds_on_player_id"
    t.index ["tournament_id"], name: "index_event_seeds_on_tournament_id"
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
    t.string "gender_pronoum"
    t.string "birthday"
    t.string "twitter_handle"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.datetime "start_at"
    t.datetime "end_at"
    t.string "venue_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "event_seeds", "players"
  add_foreign_key "event_seeds", "tournaments"
end
