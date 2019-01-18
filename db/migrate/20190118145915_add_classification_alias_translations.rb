# frozen_string_literal: true

class AddClassificationAliasTranslations < ActiveRecord::Migration[5.1]
  def change
    add_column :classification_aliases, :name_i18n, :jsonb
    add_column :classification_aliases, :description_i18n, :jsonb
    rename_column :classification_aliases, :name, :internal_name
  end
end
