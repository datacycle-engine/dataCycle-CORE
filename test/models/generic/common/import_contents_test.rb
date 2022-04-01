# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

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
end

describe DataCycleCore::Generic::Common::ImportContents do
  subject do
    DataCycleCore::Generic::Common::ImportContents
  end

  let :utility_object do
    Struct.new('UtilityObjectDummy', :external_source).new(
      Struct.new('ExternalSystemDummy', :id).new('53a82828-d3aa-4765-99ca-7aef176de1c2')
    )
  end

  it 'should process main content' do
    configuration = {
      transformations: 'DummyTransformations',
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
    end

    subject.stub :process_single_content, collect_arguments do
      subject.process_content(utility_object: utility_object, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal(utility_object, arguments.dig(0, 0))
    assert_equal('Thing', arguments.dig(0, 1))
    assert_equal(DummyTransformations.method(:do_nothing_one), arguments.dig(0, 2))
    assert_equal(data, arguments.dig(0, 3))
  end

  it 'should process single nested content' do
    configuration = {
      transformations: 'DummyTransformations',
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
    end

    subject.stub :process_single_content, collect_arguments do
      subject.process_content(utility_object: utility_object, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal(2, arguments.size)

    assert_equal(utility_object, arguments.dig(0, 0))
    assert_equal('ImageObject', arguments.dig(0, 1))
    assert_equal(DummyTransformations.method(:do_nothing_two), arguments.dig(0, 2))
    assert_equal({ 'external_key' => 'NESTED KEY' }, arguments.dig(0, 3))

    assert_equal(utility_object, arguments.dig(1, 0))
    assert_equal('Thing', arguments.dig(1, 1))
    assert_equal(DummyTransformations.method(:do_nothing_one), arguments.dig(1, 2))
    assert_equal(data, arguments.dig(1, 3))
  end

  it 'should process multiple nested contents' do
    configuration = {
      transformations: 'DummyTransformations',
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
    end

    subject.stub :process_single_content, collect_arguments do
      subject.process_content(utility_object: utility_object, raw_data: data, locale: :de, options: configuration)
    end

    assert_equal(4, arguments.size)

    assert_equal(utility_object, arguments.dig(0, 0))
    assert_equal('ImageObject', arguments.dig(0, 1))
    assert_equal(DummyTransformations.method(:do_nothing_two), arguments.dig(0, 2))
    assert_equal({ 'external_key' => 'NESTED KEY ONE' }, arguments.dig(0, 3))

    assert_equal(utility_object, arguments.dig(1, 0))
    assert_equal('ImageObject', arguments.dig(1, 1))
    assert_equal(DummyTransformations.method(:do_nothing_two), arguments.dig(1, 2))
    assert_equal({ 'external_key' => 'NESTED KEY TWO' }, arguments.dig(1, 3))

    assert_equal(utility_object, arguments.dig(2, 0))
    assert_equal('Place', arguments.dig(2, 1))
    assert_equal(DummyTransformations.method(:do_nothing_three), arguments.dig(2, 2))
    assert_equal({ 'external_key' => 'NESTED KEY THREE' }, arguments.dig(2, 3))

    assert_equal(utility_object, arguments.dig(3, 0))
    assert_equal('Thing', arguments.dig(3, 1))
    assert_equal(DummyTransformations.method(:do_nothing_one), arguments.dig(3, 2))
    assert_equal(data, arguments.dig(3, 3))
  end
end
