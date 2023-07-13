# frozen_string_literal: true

class MarkAutomaticTranslationTypes < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::Thing.where(template: false, template_name: 'Übersetzung').each do |content|
      translated_classification = DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Übersetzungstyp', 'Automatisch')
      set_manual = content.translations.map { |t| t.content.dig('translation_type') == 'manual' }&.inject(&:|)
      translated_classification = DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Übersetzungstyp', 'Manuell') if set_manual
      content.set_data_hash(data_hash: { 'translated_classification' => translated_classification }, partial_update: true, prevent_history: true)
    end
  end

  def down
  end
end
