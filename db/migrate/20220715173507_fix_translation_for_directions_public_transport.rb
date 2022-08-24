# frozen_string_literal: true

class FixTranslationForDirectionsPublicTransport < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
      UPDATE thing_translations
      SET name = 'Öffentliche Verkehrsmittel'
      FROM things
      WHERE things.id = thing_translations.thing_id AND
            template_name = 'Ergänzende Information' AND
            name = 'Öffentliche Verekehrsmittel';
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE thing_translations
      SET name = 'Öffentliche Verekehrsmittel'
      FROM things
      WHERE things.id = thing_translations.thing_id AND
            template_name = 'Ergänzende Information' AND
            name = 'Öffentliche Verkehrsmittel';
    SQL
  end
end
