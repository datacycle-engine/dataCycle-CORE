# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for the TileBorderColor feature: class_string and its private
    # tree_label / event_schedule css-class builders. enabled? and configuration
    # are stubbed so the pure list-building logic runs over lightweight doubles
    # without a real feature config or database.
    class TileBorderColorCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::Feature::TileBorderColor

      def schedule_double(next_occurrence:)
        schedule_object = Object.new
        schedule_object.define_singleton_method(:next_occurrence) { |_time, **_opts| next_occurrence }
        event = Object.new
        event.define_singleton_method(:schedule_object) { schedule_object }
        event
      end

      def loaded_aliases(full_path_names:)
        path = Object.new
        path.define_singleton_method(:full_path_names) { full_path_names }
        ca = Object.new
        ca.define_singleton_method(:classification_alias_path) { path }
        aliases = [ca]
        aliases.define_singleton_method(:loaded?) { true }
        aliases
      end

      def unloaded_aliases(tree_label_name:, internal_name:)
        tree_label = Object.new
        tree_label.define_singleton_method(:name) { tree_label_name }
        ca = Object.new
        ca.define_singleton_method(:classification_tree_label) { tree_label }
        ca.define_singleton_method(:internal_name) { internal_name }
        aliases = Object.new
        aliases.define_singleton_method(:loaded?) { false }
        aliases.define_singleton_method(:for_tree) { |_label| [ca] }
        aliases
      end

      def thing_double(template_name: 'POI', classification_aliases: nil, event_schedule: :undefined)
        obj = Object.new
        obj.define_singleton_method(:is_a?) { |klass| klass == DataCycleCore::Thing || Kernel.instance_method(:is_a?).bind_call(self, klass) }
        obj.define_singleton_method(:template_name) { template_name }
        obj.define_singleton_method(:classification_aliases) { classification_aliases }
        obj.define_singleton_method(:event_schedule) { event_schedule } unless event_schedule == :undefined
        obj
      end

      test 'filter_by_template_names is true for a blank config and for a matching template' do
        Subject.stub(:configuration, { template_name: nil }) do
          assert Subject.send(:filter_by_template_names, thing_double(template_name: 'POI'))
        end

        Subject.stub(:configuration, { template_name: ['POI'] }) do
          assert Subject.send(:filter_by_template_names, thing_double(template_name: 'POI'))
          assert_not Subject.send(:filter_by_template_names, thing_double(template_name: 'Event'))
        end
      end

      test 'tree_label_classes returns nil when no tree_label is configured' do
        Subject.stub(:configuration, { tree_label: nil }) do
          assert_nil Subject.send(:tree_label_classes, thing_double)
        end
      end

      test 'tree_label_classes builds classes from loaded classification aliases' do
        content = thing_double(classification_aliases: loaded_aliases(full_path_names: ['Region', 'Tirol']))

        result = Subject.stub(:configuration, { tree_label: 'Tirol' }) do
          Subject.send(:tree_label_classes, content)
        end

        assert_equal 1, result.size
        assert_kind_of String, result.first
      end

      test 'tree_label_classes builds classes via for_tree when aliases are not loaded' do
        content = thing_double(classification_aliases: unloaded_aliases(tree_label_name: 'Border', internal_name: 'Red'))

        result = Subject.stub(:configuration, { tree_label: 'Border' }) do
          Subject.send(:tree_label_classes, content)
        end

        assert_equal 1, result.size
        assert_kind_of String, result.first
      end

      test 'event_schedule_classes returns nil without config or event_schedule support' do
        Subject.stub(:configuration, { event_schedule: nil }) do
          assert_nil Subject.send(:event_schedule_classes, thing_double(event_schedule: [schedule_double(next_occurrence: nil)]))
        end

        Subject.stub(:configuration, { event_schedule: true }) do
          assert_nil Subject.send(:event_schedule_classes, thing_double)
        end
      end

      test 'event_schedule_classes flags past schedules when none have a next occurrence' do
        content = thing_double(event_schedule: [schedule_double(next_occurrence: nil)])

        result = Subject.stub(:configuration, { event_schedule: true }) do
          Subject.send(:event_schedule_classes, content)
        end

        assert_equal ['event_schedule_past'], result
      end

      test 'class_string concatenates tree_label and event_schedule classes for a Thing' do
        content = thing_double(
          template_name: 'POI',
          classification_aliases: loaded_aliases(full_path_names: ['Region', 'Tirol']),
          event_schedule: [schedule_double(next_occurrence: nil)]
        )

        result = Subject.stub(:enabled?, true) do
          Subject.stub(:configuration, { template_name: nil, tree_label: 'Tirol', event_schedule: true }) do
            Subject.class_string(content)
          end
        end

        assert_equal 2, result.split.size
        assert_includes result.split, 'event_schedule_past'
      end
    end
  end
end
