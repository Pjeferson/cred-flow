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

ActiveRecord::Schema[8.1].define(version: 2026_05_23_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cedente_id", null: false
    t.datetime "created_at", null: false
    t.uuid "credor_id", null: false
    t.jsonb "policy_rules", default: {}, null: false
    t.uuid "sacado_id"
    t.string "status", default: "active", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["cedente_id"], name: "index_accounts_on_cedente_id"
    t.index ["credor_id"], name: "index_accounts_on_credor_id"
    t.index ["status"], name: "index_accounts_on_status"
  end

  create_table "jwt_denylists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "ledger_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.bigint "amount_cents", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "description"
    t.string "direction", null: false
    t.string "idempotency_key", null: false
    t.uuid "payment_order_id"
    t.string "status", default: "SETTLED", null: false
    t.string "type", null: false
    t.index ["account_id", "created_at"], name: "idx_ledger_created", order: { created_at: :desc }
    t.index ["account_id", "idempotency_key"], name: "uq_ledger_idempotency", unique: true
    t.index ["account_id", "status"], name: "idx_ledger_account_status"
  end

  create_table "participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "document", null: false
    t.string "email"
    t.datetime "kyc_checked_at"
    t.string "kyc_status", default: "pending", null: false
    t.string "name", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["document"], name: "index_participants_on_document", unique: true
    t.index ["email"], name: "index_participants_on_email", unique: true
    t.index ["kyc_status"], name: "index_participants_on_kyc_status"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "accounts", "participants", column: "cedente_id"
  add_foreign_key "accounts", "participants", column: "credor_id"
  add_foreign_key "ledger_entries", "accounts"
end
