# frozen_string_literal: true

class AddIndexesToTranslations < ActiveRecord::Migration[5.0]
  def change
    ['creative_work', 'person', 'event', 'place'].each do |item|
      add_index "#{item}_history_translations".to_sym, "#{item}_history_id".to_sym, name: "#{item}_history_id_idx"
      add_index "#{item}_history_translations".to_sym, :locale, name: "#{item}_history_locale_idx"
      add_index "#{item}_translations".to_sym, "#{item}_id".to_sym, name: "#{item}_id_idx"
      add_index "#{item}_translations".to_sym, :locale, name: "#{item}_locale_idx"
    end
  end
end
