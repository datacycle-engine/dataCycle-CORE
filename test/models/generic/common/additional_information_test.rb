# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::Transformations::AdditionalInformation do
  include DataCycleCore::MinitestSpecHelper

  subject { DataCycleCore::Generic::Common::Transformations::AdditionalInformation }

  let(:external_source_id) { '11111111-1111-1111-1111-111111111111' }

  it 'adds classification references and resolves the id for each info text' do
    result = subject.add_info([{ 'type_of_info' => 'foo', 'type' => 'bar', 'external_key' => 'EK' }], external_source_id)

    assert_equal(1, result.size)
    assert_not_nil(result.first['id'])
  end

  it 'builds additional_information entries from description types' do
    data = { 'external_key' => 'EK', 'description' => 'some text' }
    result = subject.add_description_to_additional_informations(data, external_source_id, 'MyImporter')

    assert_equal(1, result['additional_information'].size)
    assert_equal('some text', result['additional_information'].first['description'])
  end

  it 'skips types whose value is blank' do
    data = { 'external_key' => 'EK', 'description' => 'text' }
    result = subject.add_description_to_additional_information_types(data, external_source_id, 'imp', ['description', 'missing'])

    assert_equal(1, result['additional_information'].size)
  end

  it 'returns an empty additional_information when external_key is blank' do
    result = subject.add_description_to_additional_information_types({ 'description' => 'x' }, external_source_id, 'imp', ['description'])

    assert_equal([], result['additional_information'])
  end

  it 'returns an empty additional_information when types are blank' do
    result = subject.add_description_to_additional_information_types({ 'external_key' => 'EK' }, external_source_id, 'imp', [])

    assert_equal([], result['additional_information'])
  end
end
