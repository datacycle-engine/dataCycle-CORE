# frozen_string_literal: true

class UpdateUniqueIndexForClassifications < ActiveRecord::Migration[8.0]
  # run db:migrate:check to check for invalid state before running this migration

  def up
    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;

      DROP INDEX IF EXISTS public.index_classifications_unique_external_source_id_and_key;

      CREATE UNIQUE INDEX IF NOT EXISTS index_classifications_unique_external_source_id_and_key ON public.classifications USING btree (external_source_id, external_key) NULLS NOT DISTINCT
      WHERE deleted_at IS NULL
        AND external_key IS NOT NULL;

      DROP INDEX IF EXISTS public.index_classification_aliases_unique_external_source_id_and_key;

      CREATE UNIQUE INDEX IF NOT EXISTS index_classification_aliases_unique_external_source_id_and_key ON public.classification_aliases USING btree (external_source_id, external_key) NULLS NOT DISTINCT
      WHERE deleted_at IS NULL
        AND external_key IS NOT NULL;
    SQL
  end
end
