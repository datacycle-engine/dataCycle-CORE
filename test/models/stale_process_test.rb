# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StaleProcessTest < DataCycleCore::TestCases::ActiveSupportTestCase
    ADDED_TEMPLATE_NAME = 'StaleProcessTestTemplate'
    ADDED_MIGRATION_VERSION = '99999999999999'

    def teardown
      revert_templates!
      remove_added_template!
      remove_added_migration!
    end

    test 'an unpinned process is never stale' do
      assert_not DataCycleCore::StaleProcess.stale?
    end

    test 'a pinned process matching the database is not stale' do
      pin_to_current_templates!

      assert_not DataCycleCore::StaleProcess.stale?
    end

    test 'a changed template schema makes the process stale' do
      pin_to_current_templates!
      mark_templates_changed!

      assert_predicate DataCycleCore::StaleProcess, :stale?
    end

    test 'the verdict latches once the process has fallen behind' do
      pin_to_current_templates!
      mark_templates_changed!

      assert_predicate DataCycleCore::StaleProcess, :stale?

      revert_templates!

      assert_predicate DataCycleCore::StaleProcess, :stale?
    end

    # StiSubclasses#create_sti_subclass_for_type_if_missing! builds the subclass for a template
    # added after the init on demand, so this process serves it and must not report itself stale -
    # a `rake dc:update` against a running stack would otherwise latch every worker it leaves up.
    test 'a template added since the pin is not evidence of staleness' do
      pin_to_current_templates!
      add_template!

      assert_not DataCycleCore::StaleProcess.stale?
    end

    test 'a pinned template that disappeared makes the process stale' do
      add_template!
      pin_to_current_templates!
      remove_added_template!

      assert_predicate DataCycleCore::StaleProcess, :stale?
    end

    # The init pins whatever it recorded, and an empty thing_templates is a set like any other:
    # dropping the pin there would leave the migrations half unwatched for the process's life.
    test 'a process pinned to no templates still notices a migration' do
      DataCycleCore::StaleProcess.pin!([])
      add_migration!

      assert_predicate DataCycleCore::StaleProcess, :stale?
    end

    test 'a database that cannot answer is not evidence of staleness' do
      pin_to_current_templates!

      ActiveRecord::Base.connection.stub(:select_one, ->(*) { raise ActiveRecord::StatementInvalid }) do
        assert_not DataCycleCore::StaleProcess.stale?
      end
    end

    private

    def pin_to_current_templates!
      DataCycleCore::StaleProcess.pin!(DataCycleCore::ThingTemplate.pluck(:template_name))
    end

    # ThingTemplate is readonly and TemplateImporter is its only writer, so the change a
    # deploy makes is applied the way StaleProcess reads it: in the database.
    def mark_templates_changed!
      ActiveRecord::Base.connection.execute("UPDATE thing_templates SET schema = schema || '{\"stale_process_test\": true}'::jsonb")
    end

    def revert_templates!
      ActiveRecord::Base.connection.execute("UPDATE thing_templates SET schema = schema - 'stale_process_test'")
    end

    def add_template!
      ActiveRecord::Base.connection.execute("INSERT INTO thing_templates (template_name, schema) VALUES ('#{ADDED_TEMPLATE_NAME}', '{}'::jsonb)")
    end

    def remove_added_template!
      ActiveRecord::Base.connection.execute("DELETE FROM thing_templates WHERE template_name = '#{ADDED_TEMPLATE_NAME}'")
    end

    def add_migration!
      ActiveRecord::Base.connection.execute("INSERT INTO schema_migrations (version) VALUES ('#{ADDED_MIGRATION_VERSION}')")
    end

    def remove_added_migration!
      ActiveRecord::Base.connection.execute("DELETE FROM schema_migrations WHERE version = '#{ADDED_MIGRATION_VERSION}'")
    end
  end
end
