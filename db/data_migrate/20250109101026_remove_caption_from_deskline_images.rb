# frozen_string_literal: true

class RemoveCaptionFromDesklineImages < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    deskline_source = DataCycleCore::ExternalSystem.find_by('name ILIKE ? OR name ILIKE ?', 'Feratel Deskline', 'Deskline')

    return if deskline_source.nil?
    return if deskline_source.import_config.to_s.include?('to_image_btm_rpt')

    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      WITH updated_translations AS (
        UPDATE thing_translations
        SET content = thing_translations.content - 'caption'
        WHERE EXISTS (
            SELECT 1
            FROM things
            WHERE things.id = thing_translations.thing_id
              AND things.external_source_id = '#{deskline_source.id}'
              AND things.template_name IN ('Bild', 'ImageObject', 'PDF', 'Audio', 'AudioObject', 'Video', 'VideoObject')
          )
          AND thing_translations.content->>'caption' IS NOT NULL
        RETURNING thing_translations.thing_id
      )
      UPDATE things
      SET cache_valid_since = NOW()
      WHERE things.id IN (
          SELECT updated_translations.thing_id
          FROM updated_translations
        );
    SQL
  end

  def down
  end
end
