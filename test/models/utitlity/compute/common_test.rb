# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class CommonTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Common
        end

        test 'copy returns the first parameter value' do
          assert_equal('first', subject.copy(computed_parameters: { 'a' => 'first', 'b' => 'second' }))
          assert_nil(subject.copy(computed_parameters: {}))
        end

        test 'take_first returns the first present value' do
          value = subject.take_first(
            computed_parameters: { 'a' => nil, 'b' => '', 'c' => 'third' },
            computed_definition: { 'type' => 'string' }
          )

          assert_equal('third', value)
        end

        test 'take_first returns nil for a scalar type when nothing is present' do
          value = subject.take_first(
            computed_parameters: { 'a' => nil, 'b' => '' },
            computed_definition: { 'type' => 'string' }
          )

          assert_nil(value)
        end

        test 'take_first returns an empty array for relation types when nothing is present' do
          ['embedded', 'linked', 'classification'].each do |type|
            value = subject.take_first(
              computed_parameters: { 'a' => nil, 'b' => [] },
              computed_definition: { 'type' => type }
            )

            assert_equal([], value, "expected [] for type #{type}")
          end
        end

        test 'copy_embedded returns an empty array for non-embedded definitions' do
          assert_equal([], subject.copy_embedded(computed_parameters: {}, computed_definition: { 'type' => 'string' }, content: nil, key: 'x'))
        end

        test 'copy_embedded collects present values from the configured embedded paths' do
          value = subject.copy_embedded(
            computed_parameters: { 'name' => ['Alpha', ''] },
            computed_definition: { 'type' => 'embedded', 'compute' => { 'value' => [{ 'attribute' => 'name' }] } },
            content: content_double,
            key: 'overlays'
          )

          assert_equal(['Alpha'], value)
        end

        test 'attribute_value_by_first_match returns the first present value across configs' do
          value = subject.attribute_value_by_first_match(
            computed_parameters: { 'title' => ['First Match'] },
            computed_definition: { 'compute' => { 'value' => [{ 'attribute' => 'missing' }, { 'attribute' => 'title' }] } },
            content: content_double,
            key: 'headline'
          )

          assert_equal('First Match', value)
        end

        private

        def content_double
          struct_double(id: nil, external_source_id: nil, translatable_property_names: [])
        end
      end
    end
  end
end
