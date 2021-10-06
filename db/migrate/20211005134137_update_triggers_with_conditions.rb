# frozen_string_literal: true

class UpdateTriggersWithConditions < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def up
    execute <<~SQL.squish
      DROP TRIGGER tsvectortypeaheadsearchupdate ON searches;

      CREATE TRIGGER tsvectortypeaheadsearchinsert
        BEFORE INSERT ON searches
        FOR EACH ROW
        EXECUTE PROCEDURE tsvector_update_trigger (words_typeahead, 'pg_catalog.simple', full_text);

      CREATE TRIGGER tsvectortypeaheadsearchupdate
        BEFORE UPDATE OF full_text ON searches
        FOR EACH ROW
        WHEN (OLD.full_text <> NEW.full_text)
        EXECUTE PROCEDURE tsvector_update_trigger (words_typeahead, 'pg_catalog.simple', full_text);

      DROP TRIGGER generate_content_content_links_trigger ON content_contents;

      CREATE TRIGGER generate_content_content_links_trigger
        AFTER INSERT ON content_contents
        FOR EACH ROW
        EXECUTE FUNCTION generate_content_content_links_trigger();

      CREATE TRIGGER update_content_content_links_trigger
        AFTER UPDATE OF content_a_id, content_b_id, relation_b ON content_contents
        FOR EACH ROW
        WHEN (OLD.content_a_id <> NEW.content_a_id OR OLD.content_b_id <> NEW.content_b_id OR OLD.relation_b <> NEW.relation_b)
        EXECUTE FUNCTION generate_content_content_links_trigger();

      DROP TRIGGER tsvectorsearchupdate ON searches;

      CREATE TRIGGER tsvectorsearchinsert
        BEFORE INSERT ON searches
        FOR EACH ROW
        EXECUTE FUNCTION tsvectorsearchupdate();

      CREATE TRIGGER tsvectorsearchupdate
        BEFORE UPDATE OF words, locale, full_text ON searches
        FOR EACH ROW
        WHEN (OLD.words <> NEW.words OR OLD.locale <> NEW.locale OR OLD.full_text <> NEW.full_text)
        EXECUTE FUNCTION tsvectorsearchupdate();

      DROP TRIGGER generate_schedule_occurences_trigger ON schedules;

      CREATE TRIGGER generate_schedule_occurences_trigger
        AFTER INSERT ON schedules
        FOR EACH ROW
        EXECUTE FUNCTION generate_schedule_occurences_trigger();

      CREATE TRIGGER update_schedule_occurences_trigger
        AFTER UPDATE OF thing_id,
        duration,
        rrule,
        dtstart,
        relation,
        exdate,
        rdate ON schedules
        FOR EACH ROW
        WHEN (OLD.thing_id <> NEW.thing_id OR OLD.duration <> NEW.duration OR OLD.rrule <> NEW.rrule OR OLD.dtstart <> NEW.dtstart OR OLD.relation <> NEW.relation OR OLD.rdate <> NEW.rdate OR OLD.exdate <> NEW.exdate)
        EXECUTE FUNCTION generate_schedule_occurences_trigger();
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP TRIGGER tsvectortypeaheadsearchinsert ON searches;
      DROP TRIGGER tsvectortypeaheadsearchupdate ON searches;

      CREATE TRIGGER tsvectortypeaheadsearchupdate
        BEFORE INSERT OR UPDATE ON searches
        FOR EACH ROW
        EXECUTE PROCEDURE tsvector_update_trigger (words_typeahead, 'pg_catalog.simple', full_text);

      DROP TRIGGER generate_content_content_links_trigger ON content_contents;
      DROP TRIGGER update_content_content_links_trigger ON content_contents;

      CREATE TRIGGER generate_content_content_links_trigger
        AFTER INSERT OR UPDATE ON content_contents
        FOR EACH ROW
        EXECUTE FUNCTION generate_content_content_links_trigger();

      DROP TRIGGER tsvectorsearchinsert ON searches;
      DROP TRIGGER tsvectorsearchupdate ON searches;

      CREATE TRIGGER tsvectorsearchupdate
        BEFORE INSERT OR UPDATE ON searches
        FOR EACH ROW
        EXECUTE FUNCTION tsvectorsearchupdate();

      DROP TRIGGER generate_schedule_occurences_trigger ON schedules;
      DROP TRIGGER update_schedule_occurences_trigger ON schedules;

      CREATE TRIGGER generate_schedule_occurences_trigger
        AFTER INSERT OR UPDATE ON schedules
        FOR EACH ROW
        EXECUTE FUNCTION generate_schedule_occurences_trigger();
    SQL
  end
end
