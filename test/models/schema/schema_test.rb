# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Schema do
  subject do
    DataCycleCore::Schema.load_schema(
      File.expand_path('../../data_types/simple_valid_templates/RandomContainersAndEntites.yml', __dir__)
    )
  end

  it 'should should provide list of available content types' do
    subject.content_types.sort.must_equal(['container', 'entity'])
  end

  it 'should should provide list of container templates' do
    subject.templates_with_content_type('container').map(&:schema_name).sort.must_equal(
      ['ContainerOne', 'ContainerTwo', 'ContainerThree'].sort
    )
  end

  it 'should should provide list of entity templates' do
    subject.templates_with_content_type('entity').map(&:schema_name).sort.must_equal(
      ['EntityOne', 'EntityTwo', 'EntityThree', 'EntityFour'].sort
    )
  end
end