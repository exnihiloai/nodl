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

ActiveRecord::Schema[8.1].define(version: 2026_06_14_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "encryption_key"
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_audit_events", force: :cascade do |t|
    t.bigint "acting_admin_id", null: false
    t.string "action", null: false
    t.jsonb "after_state"
    t.jsonb "before_state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["acting_admin_id"], name: "index_admin_audit_events_on_acting_admin_id"
    t.index ["user_id"], name: "index_admin_audit_events_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.bigint "recording_session_id", null: false
    t.string "title", null: false
    t.string "transformer_handle", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["recording_session_id", "transformer_handle"], name: "index_documents_on_recording_session_id_and_transformer_handle"
    t.index ["recording_session_id"], name: "index_documents_on_recording_session_id", unique: true
    t.index ["workspace_id", "generated_at"], name: "index_documents_on_workspace_id_and_generated_at"
  end

  create_table "legal_consents", force: :cascade do |t|
    t.datetime "accepted_at", null: false
    t.datetime "created_at", null: false
    t.string "document", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.string "version", null: false
    t.index ["user_id", "document"], name: "index_legal_consents_on_user_id_and_document"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "role", default: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id", "workspace_id"], name: "index_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "recording_integrity_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hash_algorithm", limit: 20, null: false
    t.string "hash_sha256", limit: 64, null: false
    t.datetime "hashed_at", null: false
    t.bigint "recording_session_id", null: false
    t.string "tsa_authority", limit: 255
    t.string "tsa_error", limit: 500
    t.text "tsa_proof_blob"
    t.string "tsa_proof_format", limit: 50
    t.string "tsa_provider", limit: 80, null: false
    t.string "tsa_status", limit: 30, null: false
    t.datetime "tsa_timestamp"
    t.datetime "updated_at", null: false
    t.index ["recording_session_id"], name: "index_recording_integrity_records_on_recording_session_id", unique: true
    t.index ["tsa_status"], name: "index_recording_integrity_records_on_tsa_status"
  end

  create_table "recording_sessions", force: :cascade do |t|
    t.float "audio_duration"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "error_message"
    t.datetime "processing_completed_at"
    t.datetime "processing_started_at"
    t.integer "source_kind", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "time_zone"
    t.string "title", null: false
    t.text "transcript_segments"
    t.text "transcript_text"
    t.string "transformer_handle", default: "default", null: false
    t.datetime "updated_at", null: false
    t.jsonb "waveform_peaks"
    t.string "work_path"
    t.bigint "workspace_id", null: false
    t.index ["creator_id"], name: "index_recording_sessions_on_creator_id"
    t.index ["transformer_handle"], name: "index_recording_sessions_on_transformer_handle"
    t.index ["workspace_id", "created_at"], name: "index_recording_sessions_on_workspace_id_and_created_at"
    t.index ["workspace_id", "status"], name: "index_recording_sessions_on_workspace_id_and_status"
  end

  create_table "transformer_profiles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.string "handle", null: false
    t.text "instructions", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "handle"], name: "index_transformer_profiles_on_workspace_id_and_handle", unique: true
    t.index ["workspace_id"], name: "index_transformer_profiles_one_default_per_workspace", unique: true, where: "(\"default\" = true)"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "integrity_sealing_enabled", default: false, null: false
    t.datetime "last_login_at"
    t.string "name"
    t.string "password_digest", null: false
    t.string "preferred_language", default: "en", null: false
    t.string "provider"
    t.integer "role", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "subscription_billing_cycle", default: "monthly", null: false
    t.string "subscription_plan", default: "free", null: false
    t.string "subscription_status", default: "inactive", null: false
    t.datetime "updated_at", null: false
    t.jsonb "usage_consumption", default: {}, null: false
    t.jsonb "usage_limits", default: {}, null: false
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_audit_events", "users"
  add_foreign_key "admin_audit_events", "users", column: "acting_admin_id"
  add_foreign_key "documents", "recording_sessions"
  add_foreign_key "documents", "workspaces"
  add_foreign_key "legal_consents", "users"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "recording_integrity_records", "recording_sessions", on_delete: :cascade
  add_foreign_key "recording_sessions", "users", column: "creator_id"
  add_foreign_key "recording_sessions", "workspaces"
  add_foreign_key "transformer_profiles", "workspaces"
end
