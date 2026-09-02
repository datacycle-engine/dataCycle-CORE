# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class GenericCommonArchiveContentsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::ArchiveContents

    AcDummyUtilityObject = Struct.new(:external_source, :steps_successful, :mode, :locales, :step_name) do
      def source_steps_successful?
        steps_successful
      end
    end

    # raw_data items respond to #dump → { locale => { path => external_key } }
    AcRawItem = Struct.new(:dumped) do
      def dump
        dumped
      end
    end

    # relation double exposing only what update_in_parallel needs
    AcRelation = Struct.new(:items) do
      def find_each(&)
        items.each(&)
      end
    end

    # life-cycle content double: records #archive calls and flips #archived?
    class AcFakeContent
      attr_reader :archive_calls

      def initialize(archived:, archivable: true)
        @archived = archived
        @archivable = archivable
        @archive_calls = 0
      end

      def template_name
        'Tour'
      end

      def archived?
        @archived
      end

      def archive
        @archive_calls += 1
        @archived = true if @archivable
        @archivable
      end
    end

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
    end

    def utility_object(steps_successful: true)
      AcDummyUtilityObject.new(@external_source, steps_successful, nil, [:de, :en], 'archive')
    end

    def raw_for(*keys)
      keys.map { |key| AcRawItem.new({ de: { 'id' => key } }) }
    end

    def process(contents, steps_successful: true, allowed: true)
      SUBJECT.stub(:find_contents, AcRelation.new(contents)) do
        SUBJECT.stub(:warm_life_cycle_classifications, nil) do
          DataCycleCore::Feature::LifeCycle.stub(:allowed?, allowed) do
            SUBJECT.process_content(utility_object: utility_object(steps_successful:), raw_data: raw_for('x'), locale: :de, options: { import: { external_key_path: 'id' } })
          end
        end
      end
    end

    # ---- dispatch / iterator ----

    test 'import_data forces full mode, restricts to the primary locale and dispatches to import_bulk' do
      object = utility_object
      captured = nil

      DataCycleCore::Generic::Common::ImportFunctions.stub(:import_bulk, ->(**kwargs) { captured = kwargs }) do
        SUBJECT.import_data(utility_object: object, options: { import: {} })
      end

      assert_equal :full, object.mode
      assert_equal [:de], object.locales
      assert_equal object, captured[:utility_object]
      assert_predicate captured[:iterator], :present?
      assert_predicate captured[:data_processor], :present?
    end

    test 'load_contents drops the default deletion scopes and includes deleted contents' do
      excepted = nil
      filter = Object.new
      filter.define_singleton_method(:except) do |*args|
        excepted = args
        filter
      end
      filter.define_singleton_method(:with_deleted) { filter }
      filter.define_singleton_method(:query) { [:archivable] }

      assert_equal [:archivable], SUBJECT.load_contents(filter_object: filter)
      assert_equal [:without_deleted, :without_archived], excepted
    end

    # ---- find_contents (shared LifeCycleContentProcessor) ----

    test 'find_contents resolves external keys (with prefix) for the current external source in one query' do
      captured = nil
      options = { import: { external_key_path: 'id', external_key_prefix: 'GeneralSolutions - Tour - ' } }

      DataCycleCore::Thing.stub(:where, lambda { |**kwargs|
        captured = kwargs
        :relation
      }) do
        assert_equal :relation, SUBJECT.find_contents(utility_object: utility_object, raw_data: raw_for('42', '43'), locale: :de, options:)
      end

      assert_equal ['GeneralSolutions - Tour - 42', 'GeneralSolutions - Tour - 43'], captured[:external_key]
      assert_equal @external_source.id, captured[:external_source_id]
    end

    test 'find_contents works without a prefix and skips items missing the key' do
      captured = nil
      raw_data = raw_for('42') + [AcRawItem.new({ de: {} })]

      DataCycleCore::Thing.stub(:where, lambda { |**kwargs|
        captured = kwargs
        :relation
      }) do
        SUBJECT.find_contents(utility_object: utility_object, raw_data:, locale: :de, options: { import: { external_key_path: 'id' } })
      end

      assert_equal ['42'], captured[:external_key]
    end

    test 'find_contents narrows by template_name when the step configures it' do
      where_calls = []
      relation = Object.new
      relation.define_singleton_method(:where) do |**kwargs|
        where_calls << kwargs
        relation
      end

      DataCycleCore::Thing.stub(:where, lambda { |**kwargs|
        where_calls << kwargs
        relation
      }) do
        SUBJECT.find_contents(utility_object: utility_object, raw_data: raw_for('42'), locale: :de, options: { import: { external_key_path: 'id', template_name: 'Tour' } })
      end

      assert_equal ['42'], where_calls[0][:external_key]
      assert_equal @external_source.id, where_calls[0][:external_source_id]
      assert_equal ['Tour'], where_calls[1][:template_name]
    end

    test 'find_contents raises a clear error when external_key_path is missing' do
      error = assert_raises(ArgumentError) do
        SUBJECT.find_contents(utility_object: utility_object, raw_data: raw_for('42'), locale: :de, options: { import: {} })
      end

      assert_match 'external_key_path', error.message
    end

    # ---- warm_life_cycle_classifications (shared LifeCycleContentProcessor) ----

    test 'warm_life_cycle_classifications primes the ordered-classifications cache for the first content' do
      content = Object.new
      relation = Object.new
      relation.define_singleton_method(:first) { content }
      primed = []

      DataCycleCore::Feature::LifeCycle.stub(:ordered_classifications, ->(c) { primed << c }) do
        SUBJECT.warm_life_cycle_classifications(relation)
      end

      assert_equal [content], primed
    end

    test 'warm_life_cycle_classifications is a no-op when there are no contents' do
      relation = Object.new
      relation.define_singleton_method(:first) { nil }
      primed = false

      DataCycleCore::Feature::LifeCycle.stub(:ordered_classifications, ->(_c) { primed = true }) do
        SUBJECT.warm_life_cycle_classifications(relation)
      end

      assert_not primed
    end

    # ---- update_in_parallel (shared LifeCycleContentProcessor) ----

    test 'update_in_parallel yields every content and counts truthy results' do
      seen = []

      count = SUBJECT.update_in_parallel(AcRelation.new([1, nil, 2, false])) do |content|
        seen << content
        content
      end

      assert_equal [1, nil, 2, false], seen
      assert_equal 2, count
    end

    # ---- process_content ----

    test 'process_content raises when the source steps were not successful' do
      error = assert_raises(RuntimeError) do
        process([], steps_successful: false)
      end

      assert_match 'Archive canceled', error.message
    end

    test 'process_content archives every not-yet-archived content in bulk and returns the count' do
      contents = [AcFakeContent.new(archived: false), AcFakeContent.new(archived: true), AcFakeContent.new(archived: false)]

      count = process(contents)

      assert_equal 2, count
      assert_equal [1, 0, 1], contents.map(&:archive_calls)
      assert(contents.all?(&:archived?))
    end

    test 'process_content skips contents whose template does not allow the life cycle feature' do
      contents = [AcFakeContent.new(archived: false)]

      count = process(contents, allowed: false)

      assert_equal 0, count
      assert_equal [0], contents.map(&:archive_calls)
    end

    test 'process_content returns zero when there are no matching contents' do
      assert_equal 0, process([])
    end

    # ---- counters ----

    test 'process_content counts one archived outcome per newly archived content' do
      contents = [AcFakeContent.new(archived: false), AcFakeContent.new(archived: true), AcFakeContent.new(archived: false, archivable: false)]
      events = []

      ActiveSupport::Notifications.subscribed(->(name, _s, _f, _id, payload) { events << [name, payload] }, DataCycleCore::Generic::Common::ImportCounters::EVENTS[:archived]) do
        assert_equal 1, process(contents)
      end

      assert_equal 1, events.size
      assert_equal @external_source, events.first.last[:external_system]
      assert_equal 'archive', events.first.last[:step_name]
      assert_equal 'Tour', events.first.last[:template_name]
    end
  end
end
