# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::Transformations::TransformationUtilities do
  include DataCycleCore::MinitestSpecHelper

  # the module is a mixin of instance methods → exercise it through a host that extends it
  subject do
    Class.new do
      extend DataCycleCore::Generic::Common::Transformations::TransformationUtilities
    end
  end

  let(:external_source) { Struct.new(:id).new('ext-123') }

  def utility_object(external_source:)
    object = Object.new
    object.define_singleton_method(:external_source) { external_source }
    object.define_singleton_method(:step_config) { |_config| { foo: 'bar', transformation_config: { nested: true } } }
    object
  end

  it 'resolves an attribute path through hashes and arrays' do
    assert_equal(1, subject.resolve_attribute_path({ 'a' => { 'b' => 1 } }, ['a', 'b']))
    assert_equal([1, 2], subject.resolve_attribute_path([{ 'a' => 1 }, { 'a' => 2 }], 'a'))
  end

  it 'builds keyword args from the method signature and merges the nested transformation_config' do
    object = utility_object(external_source:)
    method = ->(external_source_id:, external_source:, config:, extra:) { [external_source_id, external_source, config, extra] }

    result = subject.transformation_with_args(
      transformation_method: method,
      utility_object: object,
      config: {},
      extra: 'EXTRA'
    )

    assert_equal('ext-123', result[0])
    assert_equal(external_source, result[1])
    assert_equal({ foo: 'bar', nested: true }, result[2])
    assert_equal('EXTRA', result[3])
  end
end
