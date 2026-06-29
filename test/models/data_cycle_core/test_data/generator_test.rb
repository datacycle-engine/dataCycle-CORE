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
