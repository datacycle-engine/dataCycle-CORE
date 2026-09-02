# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module TestData
    # Integration tests for the two-pass generator against a handful of representative seeded
    # templates (classification/embedded/linked/string via Artikel, schedule via Event,
    # geographic via POI). Records are created by the system (no user); the suite's
    # around(:all) transaction rolls every record back.
    class GeneratorTest < DataCycleCore::TestCases::ActiveSupportTestCase
      REQUESTED_TEMPLATES = ['Artikel', 'Event', 'POI'].freeze
      # Produktgruppe is a non-embedded template with creatable.allowed false — the shape of an
      # imported content type an installation does not let editors create.
      NON_CREATABLE_TEMPLATE = 'Produktgruppe'
      # Every non-embedded template in the test DB that declares creatable and turns it off — the whole
      # set include_non_creatable adds. Pinned literally: the point of the option is which templates it
      # reaches, and re-deriving that from the schemas here would only restate the implementation.
      DECLARED_NON_CREATABLE_TEMPLATES = ['Katalog', 'Produkt', 'Produktgruppe', 'Produktmodel'].freeze
      # Non-embedded, not creatable, and silent about the feature — a translation shape, not a content
      # type an installation withheld from editors. include_non_creatable must not reach it.
      UNDECLARED_CREATABLE_TEMPLATE = 'Übersetzung'
      EMBEDDED_TEMPLATE = 'Action'

      before(:all) do
        @report = Generator.new(template_names: REQUESTED_TEMPLATES, life_cycle: 'Archiv').generate
        @collection = DataCycleCore::WatchList.find_by(full_path: Generator::DEFAULT_COLLECTION, user_id: nil)
      end

      test 'creates exactly one record per requested template without failures' do
        assert_equal REQUESTED_TEMPLATES.size, @report.created_count
        assert_equal 0, @report.failed_count, @report.to_s
      end

      test 'creates the records as system content without a user' do
        assert_equal REQUESTED_TEMPLATES.size, @collection.things.count

        @collection.things.each do |thing|
          assert_nil thing.created_by
        end
      end

      test 'every generated record is valid and added to the default collection' do
        assert_predicate @collection, :present?
        assert_predicate @collection, :api?
        assert_equal REQUESTED_TEMPLATES.sort, @collection.things.map(&:template_name).sort

        @collection.things.each do |thing|
          thing.valid?

          assert_empty thing.errors.full_messages, "unexpected errors for #{thing.template_name}"
        end
      end

      test 'shares the collection with the system_admin role exactly once, also on a repeated run' do
        options = { template_names: ['Artikel'], collection_name: 'TestdatenShared' }
        2.times { Generator.new(**options).generate }
        collection = DataCycleCore::WatchList.find_by(full_path: options[:collection_name], user_id: nil)

        assert_equal [['DataCycleCore::Role', DataCycleCore::Role.system_admin.id]], collection.collection_shares.pluck(:shareable_type, :shareable_id)
      end

      test 'reports properties it cannot satisfy as skipped instead of failing the record' do
        # POI references several classification trees that hold no concepts in the test DB;
        # those properties must be skipped (and reported), not cause a validation failure.
        assert_match(/Skipped properties/, @report.to_s)
        assert_equal 0, @report.failed_count
      end

      test 'fills translatable templates in every available locale' do
        translatable = @collection.things.select(&:translatable?)

        assert_operator translatable.size, :>, 0

        translatable.each do |thing|
          thing.reload

          assert_equal I18n.available_locales.sort, thing.available_locales.sort, thing.template_name

          localized_names = I18n.available_locales.map { |locale| I18n.with_locale(locale) { thing.name } }

          assert localized_names.all?(&:present?), "#{thing.template_name} is missing a localized name"
        end
      end

      test 'fills non-translatable templates in the primary locale only' do
        @collection.things.reject(&:translatable?).each do |thing|
          assert_equal 1, thing.reload.available_locales.size, thing.template_name
        end
      end

      test 'sets the requested life cycle stage on every record whose template supports it' do
        stage_id = DataCycleCore::Feature::LifeCycle.ordered_classifications.dig('Archiv', :id)
        supported = @collection.things.select { |thing| DataCycleCore::Feature::LifeCycle.allowed?(thing) }

        assert_operator supported.size, :>, 0
        assert_equal supported.size, @report.life_cycle_set_count

        supported.each do |thing|
          assert thing.reload.life_cycle_stage?(stage_id), "#{thing.template_name} not in the Archiv stage"
        end
      end

      test 'raises when the requested life cycle stage does not exist' do
        assert_raises(ArgumentError) do
          Generator.new(template_names: ['Artikel'], collection_name: 'TestdatenBadStage', life_cycle: 'NoSuchStage').generate
        end
      end

      test 'refuses a requested non-creatable template and says why' do
        error = assert_raises(ArgumentError) do
          Generator.new(template_names: [NON_CREATABLE_TEMPLATE], collection_name: 'TestdatenNonCreatable').generate
        end

        assert_includes error.message, "#{NON_CREATABLE_TEMPLATE}: not creatable — pass include_non_creatable"
      end

      test 'generates a non-creatable template when include_non_creatable is set' do
        report = Generator.new(
          template_names: [NON_CREATABLE_TEMPLATE],
          collection_name: 'TestdatenIncludeNonCreatable',
          include_non_creatable: true
        ).generate

        assert_equal 1, report.created_count
        assert_equal 0, report.failed_count, report.to_s

        collection = DataCycleCore::WatchList.find_by(full_path: 'TestdatenIncludeNonCreatable', user_id: nil)

        assert_equal [NON_CREATABLE_TEMPLATE], collection.things.map(&:template_name)
      end

      # include_non_creatable lifts the creatable filter, not the embedded one: an embedded template
      # has no record of its own and is only ever generated inside the record it is embedded in.
      test 'never generates an embedded template, even with include_non_creatable' do
        error = assert_raises(ArgumentError) do
          Generator.new(
            template_names: [EMBEDDED_TEMPLATE],
            collection_name: 'TestdatenEmbedded',
            include_non_creatable: true
          ).generate
        end

        assert_includes error.message, "#{EMBEDDED_TEMPLATE}: embedded template"
      end

      # include_non_creatable covers a schema that deliberately turns creatable off, not one that never
      # mentions it — otherwise the flag would sweep in every overlay, aggregate and translation shape.
      test 'refuses a template that never declares creatable, even with include_non_creatable' do
        error = assert_raises(ArgumentError) do
          Generator.new(
            template_names: [UNDECLARED_CREATABLE_TEMPLATE],
            collection_name: 'TestdatenUndeclaredCreatable',
            include_non_creatable: true
          ).generate
        end

        assert_includes error.message, "#{UNDECLARED_CREATABLE_TEMPLATE}: never declares the creatable feature"
      end

      # The invocation the option exists for — INCLUDE_NON_CREATABLE=true with no TEMPLATES. Generating
      # all of it takes ~40s, so what gets pinned is the selection: exactly the declared-off templates
      # are added, and none of the many that are merely silent about the feature.
      test 'include_non_creatable adds exactly the templates that declare creatable off' do
        creatable = Generator.new.send(:template_things_to_generate).map(&:template_name)
        widened = Generator.new(include_non_creatable: true).send(:template_things_to_generate).map(&:template_name)

        assert_equal DECLARED_NON_CREATABLE_TEMPLATES.sort, (widened - creatable).sort
        assert_not_includes widened, UNDECLARED_CREATABLE_TEMPLATE
        assert_not_includes widened, EMBEDDED_TEMPLATE
      end

      test 'refuses a requested template name that matches no template' do
        error = assert_raises(ArgumentError) do
          Generator.new(template_names: ['KeinSolchesTemplate'], collection_name: 'TestdatenUnknownTemplate').generate
        end

        assert_includes error.message, 'KeinSolchesTemplate: no such template'
      end

      # The case the abort exists for: a typo next to names that would generate perfectly well. A
      # partial dataset out of an explicit list reads as success — nothing may be created, and the
      # message has to name every unmatched entry, not just the first one.
      test 'refuses the whole run when only some of the requested names match' do
        thing_count = DataCycleCore::Thing.count

        error = assert_raises(ArgumentError) do
          Generator.new(
            template_names: ['Artikel', 'KeinSolchesTemplate', EMBEDDED_TEMPLATE],
            collection_name: 'TestdatenTeilweiseUnbekannt'
          ).generate
        end

        assert_includes error.message, 'cannot generate 2 of the 3 requested templates'
        assert_includes error.message, 'KeinSolchesTemplate: no such template'
        assert_includes error.message, "#{EMBEDDED_TEMPLATE}: embedded template"
        assert_equal thing_count, DataCycleCore::Thing.count
        # Not even the collection: the name is resolved (and created) only after the templates are.
        assert_nil DataCycleCore::WatchList.find_by(full_path: 'TestdatenTeilweiseUnbekannt', user_id: nil)
      end

      # No schema in this installation declares a creatable scope, so the branch is unreachable from
      # the seeded templates — but Content#creatable? has it, and without this the scope case would
      # fall through to the 'never declares the creatable feature' advice, which is both wrong and
      # would turn creation off in the UI if followed.
      test 'names the creatable scope as the reason when a template is creatable only elsewhere' do
        scoped = DataCycleCore::ThingTemplate.new(
          template_name: 'NurImImport',
          schema: { 'content_type' => 'entity', 'features' => { 'creatable' => { 'allowed' => true, 'scope' => ['import'] } } }
        )

        reason = Generator.new.send(:unmatched_reason, scoped)

        assert_includes reason, 'creatable only in scope import'
        assert_not_includes reason, 'never declares the creatable feature'
      end

      # A collection owned by a user is unreachable through collection_name, which only ever looks at
      # (and creates) system-owned collections — so an existing one has to be addressed by id.
      test 'adds the records to an existing user-owned collection given by id' do
        existing = DataCycleCore::WatchList.create!(full_path: 'Bestehende Sammlung', user: DataCycleCore::User.first!, api: true)

        assert_nil DataCycleCore::WatchList.find_by(full_path: 'Bestehende Sammlung', user_id: nil), 'a user-owned collection must be unreachable by name'

        report = Generator.new(template_names: ['Artikel'], collection_id: existing.id, collection_name: 'DarfNichtEntstehen').generate

        assert_equal 1, report.created_count
        assert_equal 0, report.failed_count, report.to_s
        assert_equal ['Artikel'], existing.reload.things.map(&:template_name)
        # The precedence is the reason the option exists: collection_name must not be looked at at all,
        # so neither a collection of that name nor a second membership for the record may appear.
        assert_nil DataCycleCore::WatchList.find_by(full_path: 'DarfNichtEntstehen', user_id: nil)
        assert_equal 1, existing.things.first.watch_lists.count
        # An existing-but-wrong id is indistinguishable from a correct one in the counts, so the
        # report has to name what the run actually wrote into — path, id and who owns it.
        assert_includes report.to_s, "Collection: Bestehende Sammlung (#{existing.id}, owned by user #{existing.user_id}, api)"
      end

      test 'names the system-owned collection it created in the report' do
        assert_includes @report.to_s, "Collection: #{Generator::DEFAULT_COLLECTION} (#{@collection.id}, system-owned, api)"
      end

      test 'raises for an unknown collection id before creating any record' do
        thing_count = DataCycleCore::Thing.count

        assert_raises(ActiveRecord::RecordNotFound) do
          Generator.new(template_names: ['Artikel'], collection_id: SecureRandom.uuid).generate
        end

        assert_equal thing_count, DataCycleCore::Thing.count
      end

      # A COLLECTION_ID typed by hand is not necessarily a uuid, and the documented RecordNotFound
      # rests on Rails casting an uncastable value to NULL rather than letting Postgres raise
      # StatementInvalid on the uuid column.
      test 'raises RecordNotFound, not StatementInvalid, for a collection id that is not a uuid' do
        assert_raises(ActiveRecord::RecordNotFound) do
          Generator.new(template_names: ['Artikel'], collection_id: 'keine-uuid').generate
        end
      end

      test 'leaves the life cycle untouched when the feature is disabled' do
        report = nil
        DataCycleCore::Feature::LifeCycle.stub(:enabled?, false) do
          report = Generator.new(template_names: ['Artikel'], collection_name: 'TestdatenNoLifeCycle', life_cycle: 'Archiv').generate
        end

        assert_equal 1, report.created_count
        assert_equal 0, report.life_cycle_set_count
        assert_equal 0, report.failed_count
      end
    end
  end
end
