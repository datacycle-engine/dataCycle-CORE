# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

module DummyImporter
  module DummyTransformations
    def self.do_nothing_one(_external_source_id = nil)
      ->(data) { data }
    end

    def self.do_nothing_two(_external_source_id = nil)
      ->(data) { data }
    end

    def self.do_nothing_three(_external_source_id = nil)
      ->(data) { data }
    end

    def self.get_external_source_id(external_source_id)
      lambda { |data|
        data['param'] = external_source_id
        data
      }
    end

    def self.get_external_source(external_source)
      lambda { |data|
        data['param'] = external_source
        data
      }
    end

    # what connectors do for nested contents: derive a key instead of reading one from the payload
    def self.add_external_key(_external_source_id = nil)
      ->(data) { data.merge('external_key' => "DERIVED - #{data['id']}") }
    end

    def self.filter_true(_data, _options) # rubocop:disable Naming/PredicateMethod
      true
    end

    def self.filter_false(_data, _options) # rubocop:disable Naming/PredicateMethod
      false
    end
  end

  module DummyNestedFilter
    def self.value?(raw_data)
      raw_data['has_value'] == 'MY VALUE'
    end
  end
end

ExternalSystemDummyStruct = Struct.new('ExternalSystemDummy', :id, :default_options)
UtilityObjectDummyStruct = Struct.new('UtilityObjectDummy', :external_source) do
  def step_config(config)
    (config || {}).with_indifferent_access
  end

  def source_name
    'dummy_collection'
  end
end

describe DataCycleCore::Generic::Common::ImportContents do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::Generic::Common::ImportContents
  end

  let :utility_object do
    UtilityObjectDummyStruct.new(
      ExternalSystemDummyStruct.new('53a82828-d3aa-4765-99ca-7aef176de1c2', {})
    )
  end

  it 'should process main content' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'external_key' => 'SOME KEY'
    }

    arguments = []

    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    subject.stub :process_single_content, collect_arguments do
      subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal(utility_object, arguments.dig(0, 0))
    assert_equal('Thing', arguments.dig(0, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_one), arguments.dig(0, 2))
    assert_equal(data, arguments.dig(0, 3))
  end

  it 'should process single nested content' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            path: 'nested',
            template: 'ImageObject',
            transformation: 'do_nothing_two'
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'external_key' => 'SOME KEY',
      'nested' => {
        'external_key' => 'NESTED KEY'
      }
    }

    arguments = []

    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    subject.stub :process_single_content, collect_arguments do
      subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal(2, arguments.size)

    assert_equal(utility_object, arguments.dig(0, 0))
    assert_equal('ImageObject', arguments.dig(0, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_two), arguments.dig(0, 2))
    assert_equal({ 'external_key' => 'NESTED KEY' }, arguments.dig(0, 3))

    assert_equal(utility_object, arguments.dig(1, 0))
    assert_equal('Thing', arguments.dig(1, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_one), arguments.dig(1, 2))
    assert_equal(data, arguments.dig(1, 3))
  end

  it 'should process single nested content using jsonpath' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            json_path: '$.nested',
            template: 'ImageObject',
            transformation: 'do_nothing_two'
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'external_key' => 'SOME KEY',
      'nested' => {
        'external_key' => 'NESTED KEY'
      }
    }

    arguments = []

    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    subject.stub :process_single_content, collect_arguments do
      subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal(2, arguments.size)
    assert_equal(utility_object, arguments.dig(0, 0))
    assert_equal('ImageObject', arguments.dig(0, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_two), arguments.dig(0, 2))
    assert_equal({ 'external_key' => 'NESTED KEY' }, arguments.dig(0, 3))

    assert_equal(utility_object, arguments.dig(1, 0))
    assert_equal('Thing', arguments.dig(1, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_one), arguments.dig(1, 2))
    assert_equal(data, arguments.dig(1, 3))
  end

  it 'should process single nested content using jsonpath and nested content filter' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            json_path: '$.nested',
            filter: {
              module: 'DummyImporter::DummyNestedFilter',
              method: 'value?'
            },
            template: 'ImageObject',
            transformation: 'do_nothing_two'
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'external_key' => 'SOME KEY',
      'nested' => [
        {
          'external_key' => 'NESTED KEY2'
        },
        {
          'external_key' => 'NESTED KEY',
          'has_value' => 'MY VALUE'
        }
      ]
    }

    arguments = []

    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    subject.stub :process_single_content, collect_arguments do
      subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal(2, arguments.size)
    assert_equal(utility_object, arguments.dig(0, 0))
    assert_equal('ImageObject', arguments.dig(0, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_two), arguments.dig(0, 2))
    assert_equal({ 'external_key' => 'NESTED KEY', 'has_value' => 'MY VALUE' }, arguments.dig(0, 3))

    assert_equal(utility_object, arguments.dig(1, 0))
    assert_equal('Thing', arguments.dig(1, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_one), arguments.dig(1, 2))
    assert_equal(data, arguments.dig(1, 3))
  end

  it 'should hand the key of the base data down to nested contents' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            path: 'nested',
            template: 'ImageObject',
            transformation: 'do_nothing_two'
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'dc_external_id' => 'BASE KEY',
      'external_key' => 'SOME KEY',
      'nested' => {
        'external_key' => 'NESTED KEY'
      }
    }

    arguments = []

    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    DataCycleCore::Generic::Common::ImportFunctions.stub :process_step, collect_arguments do
      subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal({ 'external_key' => 'NESTED KEY', 'dc_external_id' => 'BASE KEY' }, arguments.dig(0, 0, :raw_data))
    assert_equal({ 'external_key' => 'NESTED KEY' }, data['nested'])
    assert_equal(data, arguments.dig(1, 0, :raw_data))
  end

  it 'should fall back to the id of the base data for nested contents' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            path: 'nested',
            template: 'ImageObject',
            transformation: 'do_nothing_two'
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'id' => 'BASE ID',
      'nested' => {
        'external_key' => 'NESTED KEY',
        'id' => 'NESTED ID'
      }
    }

    arguments = []

    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    DataCycleCore::Generic::Common::ImportFunctions.stub :process_step, collect_arguments do
      subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal({ 'external_key' => 'NESTED KEY', 'id' => 'NESTED ID', 'dc_external_id' => 'BASE ID' }, arguments.dig(0, 0, :raw_data))
  end

  it 'should process multiple nested contents' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            path: 'nested_one',
            template: 'ImageObject',
            transformation: 'do_nothing_two'
          }, {
            path: 'nested_two',
            template: 'Place',
            transformation: 'do_nothing_three'
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'external_key' => 'SOME KEY',
      'nested_one' => [
        { 'external_key' => 'NESTED KEY ONE' },
        { 'external_key' => 'NESTED KEY TWO' }
      ],
      'nested_two' => { 'external_key' => 'NESTED KEY THREE' }
    }

    arguments = []

    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    subject.stub :process_single_content, collect_arguments do
      subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal(4, arguments.size)

    assert_equal(utility_object, arguments.dig(0, 0))
    assert_equal('ImageObject', arguments.dig(0, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_two), arguments.dig(0, 2))
    assert_equal({ 'external_key' => 'NESTED KEY ONE' }, arguments.dig(0, 3))

    assert_equal(utility_object, arguments.dig(1, 0))
    assert_equal('ImageObject', arguments.dig(1, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_two), arguments.dig(1, 2))
    assert_equal({ 'external_key' => 'NESTED KEY TWO' }, arguments.dig(1, 3))

    assert_equal(utility_object, arguments.dig(2, 0))
    assert_equal('Place', arguments.dig(2, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_three), arguments.dig(2, 2))
    assert_equal({ 'external_key' => 'NESTED KEY THREE' }, arguments.dig(2, 3))

    assert_equal(utility_object, arguments.dig(3, 0))
    assert_equal('Thing', arguments.dig(3, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_one), arguments.dig(3, 2))
    assert_equal(data, arguments.dig(3, 3))
  end

  it 'does not processes data when data_filter function returns false' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        data_filter: {
          module: 'DummyImporter::DummyTransformations',
          method: 'filter_false',
          parameters: {
            tree_label: 'test'
          }
        },
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'external_key' => 'SOME KEY'
    }

    arguments = []

    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    result = nil

    subject.stub(:process_single_content, collect_arguments) do
      result = subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
    end

    assert_nil(result)
  end

  it 'processes data when data_filter function returns true' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        data_filter: {
          module: 'DummyImporter::DummyTransformations',
          method: 'filter_true',
          parameters: {
            tree_label: 'test'
          }
        },
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'external_key' => 'SOME KEY'
    }

    arguments = []

    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    subject.stub(:process_single_content, collect_arguments) do
      subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal(utility_object, arguments.dig(0, 0))
    assert_equal('Thing', arguments.dig(0, 1))
    assert_equal(DummyImporter::DummyTransformations.method(:do_nothing_one), arguments.dig(0, 2))
    assert_equal(data, arguments.dig(0, 3))
  end

  it 'should store the mongo key of the base data on a nested content' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            path: 'nested',
            template: 'ImageObject',
            transformation: 'do_nothing_two'
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'dc_external_id' => 'BASE KEY',
      'external_key' => 'SOME KEY',
      'nested' => {
        'external_key' => 'NESTED KEY',
        'id' => 'NESTED ID'
      }
    }

    arguments = []

    get_dummy_template = ->(template_name) { DataCycleCore::ThingTemplate.new(template_name:, schema: { 'name' => template_name }).template_thing }
    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    DataCycleCore::Generic::Common::ImportFunctions.stub :load_template, get_dummy_template do
      DataCycleCore::Generic::Common::ImportFunctions.stub :create_or_update_content, collect_arguments do
        subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
      end
    end

    assert_equal('BASE KEY', arguments.dig(0, 0, :data)['dc_mongo_key'])
    assert_equal('BASE KEY', arguments.dig(1, 0, :data)['dc_mongo_key'])
  end

  # gem2go and friends whitelist the nested payload; the key is filtered out before the transformation
  # sees it, but add_mongo_infos reads the raw data handed to process_step, not the filtered one
  it 'should store the mongo key even when the nested content is whitelisted' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            path: 'nested',
            template: 'ImageObject',
            transformation: 'do_nothing_two',
            before: {
              whitelist: [['external_key']]
            }
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'dc_external_id' => 'BASE KEY',
      'external_key' => 'SOME KEY',
      'nested' => {
        'external_key' => 'NESTED KEY',
        'drop_me' => 'x'
      }
    }

    arguments = []

    get_dummy_template = ->(template_name) { DataCycleCore::ThingTemplate.new(template_name:, schema: { 'name' => template_name }).template_thing }
    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    DataCycleCore::Generic::Common::ImportFunctions.stub :load_template, get_dummy_template do
      DataCycleCore::Generic::Common::ImportFunctions.stub :create_or_update_content, collect_arguments do
        subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
      end
    end

    assert_equal('BASE KEY', arguments.dig(0, 0, :data)['dc_mongo_key'])
  end

  # the key handed down must not make a nested content worth importing that was skipped before
  it 'should still skip a blank nested content' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            path: 'nested',
            template: 'ImageObject',
            transformation: 'add_external_key'
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'dc_external_id' => 'BASE KEY',
      'external_key' => 'SOME KEY',
      'nested' => {
        'name' => nil
      }
    }

    arguments = []

    get_dummy_template = ->(template_name) { DataCycleCore::ThingTemplate.new(template_name:, schema: { 'name' => template_name }).template_thing }
    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    DataCycleCore::Generic::Common::ImportFunctions.stub :load_template, get_dummy_template do
      DataCycleCore::Generic::Common::ImportFunctions.stub :create_or_update_content, collect_arguments do
        subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
      end
    end

    assert_equal(1, arguments.size)
    assert_equal('SOME KEY', arguments.dig(0, 0, :data)['external_key'])
  end

  it 'should still skip a nested content that is nothing but an id' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        nested_contents: [
          {
            path: 'nested',
            template: 'ImageObject',
            transformation: 'add_external_key'
          }
        ],
        main_content: {
          template: 'Thing',
          transformation: 'do_nothing_one'
        }
      }
    }

    data = {
      'dc_external_id' => 'BASE KEY',
      'external_key' => 'SOME KEY',
      'nested' => {
        'id' => 'NESTED ID'
      }
    }

    arguments = []

    get_dummy_template = ->(template_name) { DataCycleCore::ThingTemplate.new(template_name:, schema: { 'name' => template_name }).template_thing }
    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    DataCycleCore::Generic::Common::ImportFunctions.stub :load_template, get_dummy_template do
      DataCycleCore::Generic::Common::ImportFunctions.stub :create_or_update_content, collect_arguments do
        subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
      end
    end

    assert_equal(1, arguments.size)
    assert_equal('SOME KEY', arguments.dig(0, 0, :data)['external_key'])
  end

  it 'should give the external_source id as parameter to the transformation' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        main_content: {
          template: 'Thing',
          transformation: 'get_external_source_id'
        }
      }
    }

    data = {
      'external_key' => 'SOME KEY'
    }
    arguments = []

    get_dummy_template = ->(template_name) { DataCycleCore::ThingTemplate.new(template_name:, schema: { 'name' => template_name }).template_thing }
    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    DataCycleCore::Generic::Common::ImportFunctions.stub :load_template, get_dummy_template do
      DataCycleCore::Generic::Common::ImportFunctions.stub :create_or_update_content, collect_arguments do
        subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
      end
    end

    assert_predicate(data['param'], :uuid?)
  end

  it 'should give the external_source as parameter to the transformation' do
    configuration = {
      transformations: 'DummyImporter::DummyTransformations',
      import: {
        main_content: {
          template: 'Thing',
          transformation: 'get_external_source'
        }
      }
    }

    data = {
      'external_key' => 'SOME KEY'
    }
    arguments = []

    get_dummy_template = ->(template_name) { DataCycleCore::ThingTemplate.new(template_name:, schema: { 'name' => template_name }).template_thing }
    collect_arguments = lambda do |*args|
      arguments << args
      nil
    end

    DataCycleCore::Generic::Common::ImportFunctions.stub :load_template, get_dummy_template do
      DataCycleCore::Generic::Common::ImportFunctions.stub :create_or_update_content, collect_arguments do
        subject.process_content(utility_object:, raw_data: data, locale: :de, options: configuration)
      end
    end

    assert(data['param'].is_a?(Struct::ExternalSystemDummy))
  end
end
