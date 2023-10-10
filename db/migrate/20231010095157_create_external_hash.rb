# frozen_string_literal: true

# This migration comes from active_storage (originally 20170806125915)
class CreateExternalHash < ActiveRecord::Migration[5.2]
  def change
    create_table :external_hashes, id: :uuid do |t|
      t.uuid      :external_source_id
      t.string    :external_key
      t.string    :hash_value
      t.datetime  :seen_at
      t.timestamps

      t.index [:external_source_id, :external_key], name: 'index_external_hash_on_external_source_id_and_external_key', unique: true, using: :btree
    end
  end
end
