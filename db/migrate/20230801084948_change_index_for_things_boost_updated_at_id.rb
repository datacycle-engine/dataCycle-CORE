# frozen_string_literal: true

class ChangeIndexForThingsBoostUpdatedAtId < ActiveRecord::Migration[6.1]
  def change
    remove_index :things, [:boost, :updated_at, :id], name: 'index_things_on_boost_updated_at_id', if_exists: true
    add_index :things, [:boost, :updated_at, :id], order: { boost: 'DESC NULLS LAST', updated_at: 'DESC NULLS LAST', id: 'DESC NULLS LAST' }, name: 'index_things_on_boost_updated_at_id', if_not_exists: true
  end
end
