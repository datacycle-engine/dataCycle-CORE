# frozen_string_literal: true

class AddIndexesToTranslations < ActiveRecord::Migration[5.0]
  def change
    ['creative_work', 'person', 'event', 'place'].each do |item|
      add_index :"#{item}_history_translations", :"#{item}_history_id", name: "#{item}_history_id_idx"
      add_index :"#{item}_history_translations", :locale, name: "#{item}_history_locale_idx"
      add_index :"#{item}_translations", :"#{item}_id", name: "#{item}_id_idx"
      add_index :"#{item}_translations", :locale, name: "#{item}_locale_idx"
    end
  end
end
