# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      # Covers #concat through a real template: a hand-built virtual_definition matches whatever the
      # implementation reads, so only the trip through properties_for catches a wrong nesting level.
      class ClassificationConcatSeparatorTest < DataCycleCore::TestCases::ActiveSupportTestCase
        CONCEPT_NAMES = ['SmartCrop', 'Zentriert'].freeze

        before(:all) do
          @content = create_content(
            'Virtual-Classification-Concat',
            { name: 'With gravity', gravity: get_classification_ids('Gravity', *CONCEPT_NAMES) }
          )
          @without_classifications = create_content(
            'Virtual-Classification-Concat',
            { name: 'Without gravity' }
          )
        end

        # Nothing on the read path applies an ORDER BY, so pin the separator, not the order.
        def assert_concat(separator, actual)
          assert_includes(CONCEPT_NAMES.permutation.map { |names| names.join(separator) }, actual)
        end

        # a single classification would join the same way whatever the separator is
        test 'the fixture assigns more than one classification' do
          assert_equal(CONCEPT_NAMES.size, @content.gravity.size)
        end

        test 'concat joins with ", " when the template configures no separator' do
          assert_concat(', ', @content.gravity_default)
        end

        test 'concat joins with the separator configured in the template' do
          assert_concat(' | ', @content.gravity_pipe)
          assert_concat(' | ', @content.load_virtual_attribute('gravity_pipe'))
        end

        test 'a separator configured as an empty string is used, not replaced by the default' do
          assert_concat('', @content.gravity_glued)
        end

        test 'a configured separator does not turn no classifications into an empty string' do
          assert_nil(@without_classifications.gravity_pipe)
          assert_nil(@without_classifications.gravity_default)
        end
      end
    end
  end
end
