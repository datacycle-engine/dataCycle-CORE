# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    module Templates
      # Coverage for TemplateTransformer's private helpers: the missing-mixin error
      # path, keys_from_parameters and the condition_* predicates driven via the
      # property condition system. All pure hash logic, no templates loaded from disk.
      class TemplateTransformerCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def transformer(template = { name: 'TestTemplate' }, **)
          DataCycleCore::MasterData::Templates::TemplateTransformer.new(template:, **)
        end

        test 'replace_mixin_property records an error when the mixin is missing' do
          tt = transformer

          assert_equal({}, tt.send(:replace_mixin_property, 'my_prop', :missing_mixin, {}))
          assert(tt.instance_variable_get(:@errors).any? { |e| e.include?('mixin for missing_mixin not found') })
        end

        test 'keys_from_parameters returns [] for blank and the first present parameter set' do
          tt = transformer

          assert_equal([], tt.send(:keys_from_parameters, nil))
          assert_equal(['a.b'], tt.send(:keys_from_parameters, { compute: { parameters: ['a.b'] } }))
          assert_equal(['c.d'], tt.send(:keys_from_parameters, { default_value: { parameters: ['c.d'] } }))
        end

        test 'allowed_property? records an error for an unknown condition' do
          tt = transformer

          tt.send(:allowed_property?, key: 'prop', property: { condition: { 'no_such_condition' => 'x' } }, properties: {})

          assert(tt.instance_variable_get(:@errors).any? { |e| e.include?('method not found') })
        end

        test 'condition_parameters_exist? checks the first parameter path segment' do
          tt = transformer

          assert(tt.send(:condition_parameters_exist?, property: {}, properties: {}))
          assert(tt.send(:condition_parameters_exist?, property: { compute: { parameters: ['foo.bar'] } }, properties: { 'foo' => {} }))
          assert_not(tt.send(:condition_parameters_exist?, property: { compute: { parameters: ['foo.bar'] } }, properties: { 'baz' => {} }))
        end

        test 'condition_parameters_exist_with_type? matches the referenced parameter type' do
          tt = transformer

          assert(tt.send(:condition_parameters_exist_with_type?, property: {}, properties: {}, value: 'string'))
          assert(tt.send(:condition_parameters_exist_with_type?, property: { compute: { parameters: ['foo.bar'] } }, properties: { 'foo' => { 'type' => 'string' } }, value: 'string'))
          assert_not(tt.send(:condition_parameters_exist_with_type?, property: { compute: { parameters: ['foo.bar'] } }, properties: { 'foo' => { 'type' => 'number' } }, value: 'string'))
        end

        test 'condition_feature_allowed? falls back to the template feature config' do
          tt = transformer({ name: 'T', features: { 'my_feature' => { 'allowed' => true } } })

          DataCycleCore.stub(:features, { 'my_feature' => { 'enabled' => true, 'allowed' => false } }) do
            assert(tt.send(:condition_feature_allowed?, value: 'my_feature'))
          end

          DataCycleCore.stub(:features, { 'my_feature' => { 'enabled' => false } }) do
            assert_not(tt.send(:condition_feature_allowed?, value: 'my_feature'))
          end
        end
      end
    end
  end
end
