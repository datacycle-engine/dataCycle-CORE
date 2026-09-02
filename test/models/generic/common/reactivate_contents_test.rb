# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class GenericCommonReactivateContentsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::ReactivateContents

    RcDummyUtilityObject = Struct.new(:external_source, :steps_successful, :mode, :locales) do
      def source_steps_successful?
        steps_successful
      end
    end

    RcRawItem = Struct.new(:dumped) do
      def dump
        dumped
      end
    end

    RcRelation = Struct.new(:items) do
      def find_each(&)
        items.each(&)
      end
    end

    # life-cycle content double: records the classification id it was reset to. Includes the real
    # #reactivate so the stage resolution under test is the one Feature::DataHash::LifeCycle does.
    class RcFakeContent
      include DataCycleCore::Feature::DataHash::LifeCycle

      attr_reader :stage_set_to

      def initialize(archived:)
        @archived = archived
        @stage_set_to = nil
      end

      def archived?
        @archived
      end

      def set_life_cycle_classification(classification_id, _user, *_history_and_computed_flags)
        @stage_set_to = classification_id
      end
    end

    ORDERED_STAGES = { 'Freigegeben' => { 'id' => 'stage-freigegeben' }, 'Aktuell' => { 'id' => 'stage-aktuell' } }.with_indifferent_access

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
    end

    def utility_object(steps_successful: true)
      RcDummyUtilityObject.new(@external_source, steps_successful, nil, [:de, :en])
    end

    def raw_for(*keys)
      keys.map { |key| RcRawItem.new({ de: { 'id' => key } }) }
    end

    def process(contents, import: { external_key_path: 'id' }, steps_successful: true, allowed: true, ordered: ORDERED_STAGES)
      SUBJECT.stub(:find_contents, RcRelation.new(contents)) do
        SUBJECT.stub(:warm_life_cycle_classifications, nil) do
          DataCycleCore::Feature::LifeCycle.stub(:allowed?, allowed) do
            DataCycleCore::Feature::LifeCycle.stub(:ordered_classifications, ordered) do
              SUBJECT.process_content(utility_object: utility_object(steps_successful:), raw_data: raw_for('x'), locale: :de, options: { import: })
            end
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

    test 'load_contents runs the query without dropping deletion scopes' do
      filter = Object.new
      filter.define_singleton_method(:query) { [:seen] }

      assert_equal [:seen], SUBJECT.load_contents(filter_object: filter)
    end

    # ---- process_content ----

    test 'process_content raises when the source steps were not successful' do
      error = assert_raises(RuntimeError) do
        process([], steps_successful: false)
      end

      assert_match 'Reactivate canceled', error.message
    end

    test 'process_content reactivates only archived contents to the configured stage and returns the count' do
      contents = [RcFakeContent.new(archived: true), RcFakeContent.new(archived: false), RcFakeContent.new(archived: true)]

      count = process(contents, import: { external_key_path: 'id', life_cycle_stage: 'Freigegeben' })

      assert_equal 2, count
      assert_equal ['stage-freigegeben', nil, 'stage-freigegeben'], contents.map(&:stage_set_to)
    end

    test 'process_content falls back to the default stage when none is configured' do
      contents = [RcFakeContent.new(archived: true)]

      count = process(contents) # no life_cycle_stage → Feature::LifeCycle::DEFAULT_ACTIVE_NAME ("Aktuell")

      assert_equal 1, count
      assert_equal 'stage-aktuell', contents.first.stage_set_to
    end

    test 'process_content skips contents whose template does not allow the life cycle feature' do
      contents = [RcFakeContent.new(archived: true)]

      count = process(contents, allowed: false)

      assert_equal 0, count
      assert_nil contents.first.stage_set_to
    end

    test 'process_content leaves contents untouched when the target stage cannot be resolved' do
      contents = [RcFakeContent.new(archived: true)]

      count = process(contents, ordered: {}.with_indifferent_access)

      assert_equal 0, count
      assert_nil contents.first.stage_set_to
    end

    test 'process_content returns zero when there are no matching contents' do
      assert_equal 0, process([])
    end
  end
end
