# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    class ThingRendererV4Test < DataCycleCore::TestCases::ActiveSupportTestCase
      test 'includes and fields as string get transformed correctly' do
        renderer = DataCycleCore::ApiRenderer::ThingRendererV4.new(
          include_parameters: 'field1,field2.subfield1,field2.subfield2',
          fields_parameters: 'field1,field2.subfield1,field2.subfield2'
        )

        assert_equal(
          [['field1'], ['field2', 'subfield1'], ['field2', 'subfield2']],
          renderer.instance_variable_get(:@params)[:include_parameters]
        )
        assert_equal(
          [['field1'], ['field2', 'subfield1'], ['field2', 'subfield2']],
          renderer.instance_variable_get(:@params)[:fields_parameters]
        )
      end

      test 'includes and fields as array get transformed correctly' do
        renderer = DataCycleCore::ApiRenderer::ThingRendererV4.new(
          include_parameters: ['field1', 'field2.subfield1', 'field2.subfield2'],
          fields_parameters: ['field1', 'field2.subfield1', 'field2.subfield2']
        )

        assert_equal(
          [['field1'], ['field2', 'subfield1'], ['field2', 'subfield2']],
          renderer.instance_variable_get(:@params)[:include_parameters]
        )
        assert_equal(
          [['field1'], ['field2', 'subfield1'], ['field2', 'subfield2']],
          renderer.instance_variable_get(:@params)[:fields_parameters]
        )
      end

      test 'nested includes and fields get transformed correctly' do
        renderer = DataCycleCore::ApiRenderer::ThingRendererV4.new(
          include_parameters: [['field1.subfield1'], ['field1.subfield2'], ['field2.subfield1']],
          fields_parameters: [['field1.subfield1'], ['field1.subfield2'], ['field2.subfield1']]
        )

        assert_equal(
          [['field1', 'subfield1'], ['field1', 'subfield2'], ['field2', 'subfield1']],
          renderer.instance_variable_get(:@params)[:include_parameters]
        )
        assert_equal(
          [['field1', 'subfield1'], ['field1', 'subfield2'], ['field2', 'subfield1']],
          renderer.instance_variable_get(:@params)[:fields_parameters]
        )
      end

      test 'deeply nested includes and fields get transformed correctly' do
        renderer = DataCycleCore::ApiRenderer::ThingRendererV4.new(
          include_parameters: [[['field1'], ['subfield1']], ['field1.subfield2'], ['field2.subfield1']],
          fields_parameters: [[['field1'], ['subfield1']], ['field1.subfield2'], ['field2.subfield1']]
        )

        assert_equal(
          [['field1', 'subfield1'], ['field1', 'subfield2'], ['field2', 'subfield1']],
          renderer.instance_variable_get(:@params)[:include_parameters]
        )
        assert_equal(
          [['field1', 'subfield1'], ['field1', 'subfield2'], ['field2', 'subfield1']],
          renderer.instance_variable_get(:@params)[:fields_parameters]
        )
      end
    end
  end
end
