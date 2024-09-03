# frozen_string_literal: true

class AddTriggerForChangingTemplateNameInThings < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION update_template_name_dependent_in_things() RETURNS TRIGGER LANGUAGE plpgsql AS $$
      DECLARE template_data record;

      BEGIN
      SELECT tt.boost, tt.content_type
      FROM thing_templates tt
      WHERE tt.template_name = NEW.template_name
      LIMIT 1 INTO template_data;

      NEW.boost = template_data.boost;
      NEW.content_type = template_data.content_type;
      NEW.cache_valid_since = NOW();

      RETURN NEW;

      END;

      $$;

      CREATE TRIGGER update_template_name_in_things_trigger BEFORE
      UPDATE OF template_name ON things FOR EACH ROW
        WHEN (OLD.template_name IS DISTINCT FROM NEW.template_name)
        EXECUTE FUNCTION update_template_name_dependent_in_things();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS update_template_name_in_things_trigger ON things;
      DROP FUNCTION IF EXISTS update_template_name_dependent_in_things();
    SQL
  end
end
