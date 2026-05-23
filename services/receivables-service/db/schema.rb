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

ActiveRecord::Schema[8.1].define(version: 2026_05_23_300002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ccbs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.decimal "annual_rate", precision: 5, scale: 4, null: false
    t.bigint "discount_cents", default: 0, null: false
    t.date "first_due_date", null: false
    t.integer "installment_count", null: false
    t.datetime "issued_at", default: -> { "now()" }, null: false
    t.bigint "net_cents", null: false
    t.bigint "principal_cents", null: false
    t.datetime "settled_at"
    t.string "status", default: "active", null: false
    t.index ["account_id", "status"], name: "idx_ccbs_account"
    t.check_constraint "installment_count > 0", name: "chk_ccbs_installment_count"
    t.check_constraint "principal_cents > 0", name: "chk_ccbs_principal_positive"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'settled'::character varying::text, 'defaulted'::character varying::text, 'cancelled'::character varying::text])", name: "chk_ccbs_status"
  end

  create_table "installments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.uuid "ccb_id", null: false
    t.datetime "created_at", null: false
    t.date "due_date", null: false
    t.integer "number", null: false
    t.date "paid_at"
    t.bigint "paid_cents", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["ccb_id", "number"], name: "uq_installment_number", unique: true
    t.index ["ccb_id", "status"], name: "idx_installments_ccb"
    t.index ["ccb_id"], name: "index_installments_on_ccb_id"
    t.index ["due_date"], name: "idx_installments_due", where: "((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('partially_paid'::character varying)::text]))"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'partially_paid'::character varying::text, 'paid'::character varying::text, 'overdue'::character varying::text])", name: "chk_installments_status"
  end

  add_foreign_key "installments", "ccbs"
end
