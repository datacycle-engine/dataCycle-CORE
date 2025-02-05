# frozen_string_literal: true

class AddIndexToHistories < ActiveRecord::Migration[5.0]
  def change
    ['creative_work', 'person', 'event', 'place'].each do |item|
      add_index :"#{item}_histories", :"#{item}_id", name: "#{item}_id_foreign_key_idx"
      add_index :"#{item}_histories", :id, name: "#{item}_histories_id_idx"
    end
  end
end
