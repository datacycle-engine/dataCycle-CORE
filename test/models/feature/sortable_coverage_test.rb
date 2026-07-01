# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for the Feature::Sortable object-browser option builder and the
    # advanced-attributes branch of to_sort_options.
    class SortableCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      test 'available_object_browser_options builds advanced-attribute sort options' do
        user = struct_double(ui_locale: :de)
        config = { 'advanced_attributes' => { 'foo' => 'bar' } }

        DataCycleCore::Feature::Sortable.stub(:enabled?, true) do
          result = DataCycleCore::Feature::Sortable.available_object_browser_options(config, user)

          assert(result.any? { |option| option[:method] == 'advanced_attribute_foo' })
        end
      end

      test 'available_object_browser_options returns an empty list when disabled' do
        DataCycleCore::Feature::Sortable.stub(:enabled?, false) do
          assert_empty(DataCycleCore::Feature::Sortable.available_object_browser_options({}, nil))
        end
      end
    end
  end
end
