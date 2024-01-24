# frozen_string_literal: true

class RemoveUnusedFunctions < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS generate_collected_cl_content_relations_transitive(classification_contents);

      DROP FUNCTION IF EXISTS generate_collected_cl_content_relations_transitive(
        content_ids uuid [],
        excluded_classification_ids uuid []
      );
    SQL

    remove_foreign_key :things, :thing_templates, column: :template_name, primary_key: :template_name
    remove_foreign_key :thing_histories, :thing_templates, column: :template_name, primary_key: :template_name
    add_foreign_key :things, :thing_templates, column: :template_name, primary_key: :template_name, on_delete: :cascade, on_update: :cascade
    add_foreign_key :thing_histories, :thing_templates, column: :template_name, primary_key: :template_name, on_delete: :cascade, on_update: :cascade
  end
end
