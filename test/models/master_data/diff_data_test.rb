# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::DiffData do
  subject do
    DataCycleCore::MasterData::DiffData
  end

  describe 'loaded template_data' do
    let(:data_template) do
      {
        name: 'App',
        type: 'object',
        content_type: 'entity',
        schema_type: 'CreativeWork',
        boost: 10.0,
        properties: {
          id: {
            label: 'id',
            type: 'key'
          },
          headline: {
            label: 'Arbeitstitel',
            type: 'string',
            storage_location: 'column',
            search: true,
            validations: { minLength: 1 }
          },
          headline_external: {
            label: 'Titel',
            type: 'string',
            storage_location: 'translated_value',
            search: true,
            validations: { minLength: 1 }
          }
        }
      }
    end

    let(:data) do
      { 'headline' => 'test' }
    end

    it 'checks that template a is given' do
      differ = subject.new.diff(a: data, schema_a: nil, b: data, schema_b: data_template.deep_stringify_keys)
      assert differ.errors[:error].size == 1
    end

    it 'uses template a as template b if it is not given' do
      differ = subject.new.diff(a: data, schema_a: data_template.deep_stringify_keys, b: data, schema_b: nil)
      assert differ.errors[:error].size.zero?
    end

    it 'checks that both templates have the same name' do
      schema_a = data_template.deep_dup
      schema_b = data_template.deep_dup
      schema_b['name'] = 'test'
      differ = subject.new.diff(a: data, schema_a: schema_a.deep_stringify_keys, b: data, schema_b: schema_b.deep_stringify_keys)
      assert differ.errors[:error].size == 1
    end

    it 'checks that both templates have the same content' do
      schema_a = data_template.deep_dup
      schema_b = data_template.deep_dup
      schema_b.delete(:properties)
      schema_b[:properties] = schema_a[:properties].except(:headline_external)
      schema_b[:properties][:name_external] = {
        label: 'Titel',
        type: 'string',
        storage_location: 'translated_value',
        search: true,
        validations: { minLength: 1 }
      }
      differ = subject.new.diff(a: data, schema_a: schema_a.deep_stringify_keys, b: data, schema_b: schema_b.deep_stringify_keys)
      assert differ.errors[:error].size == 1
      assert differ.errors[:info].size == 1
    end
  end
end
