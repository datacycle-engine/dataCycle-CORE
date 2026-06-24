# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::Transformations::RatingTransformations do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::Generic::Common::Transformations::RatingTransformations
  end

  it 'should transform single rating value' do
    raw_data = { 'rating_value' => 7 }

    transformed_data = subject.collect_ratings(raw_data, [['rating_value']], '')

    assert_equal(7, transformed_data['aggregate_rating'][0]['rating_value'])
    assert_equal('rating_value', transformed_data['aggregate_rating'][0]['name'])
  end

  it 'should transform multiple rating values' do
    raw_data = {
      'rating_value_1' => 7,
      'rating_value_2' => 5
    }

    transformed_data = subject.collect_ratings(raw_data, [['rating_value_1'], ['rating_value_2']], '')

    assert_equal(7, transformed_data['aggregate_rating'][0]['rating_value'])
    assert_equal('rating_value_1', transformed_data['aggregate_rating'][0]['name'])
    assert_equal(5, transformed_data['aggregate_rating'][1]['rating_value'])
    assert_equal('rating_value_2', transformed_data['aggregate_rating'][1]['name'])
  end

  it 'should ignore rating values which are too small' do
    raw_data = {
      'rating_value_1' => 7,
      'rating_value_2' => 0
    }

    transformed_data = subject.collect_ratings(raw_data, [['rating_value_1', 1], ['rating_value_2', 1]], '')

    assert_equal(1, transformed_data['aggregate_rating'].size)
  end

  it 'should ignore rating values which are too big' do
    raw_data = {
      'rating_value_1' => 7,
      'rating_value_2' => 5
    }

    transformed_data = subject.collect_ratings(raw_data, [['rating_value_1', 1, 6], ['rating_value_2', 1, 6]], '')

    assert_equal(1, transformed_data['aggregate_rating'].size)
  end

  it 'should set minimum and maximum values' do
    raw_data = {
      'rating_value' => 4
    }

    transformed_data = subject.collect_ratings(raw_data, [['rating_value', 1, 6]], '')

    assert_equal(1, transformed_data['aggregate_rating'].size)
    assert_equal(1, transformed_data['aggregate_rating'][0]['worst_rating'])
    assert_equal(6, transformed_data['aggregate_rating'][0]['best_rating'])
  end

  it 'should set external key and create external reference' do
    raw_data = {
      'external_key' => 'EXTERNAL KEY',
      'rating_value' => 3
    }

    transformed_data = subject.collect_ratings(raw_data, [['rating_value', 1, 6]], '', '123454321')

    assert_equal(1, transformed_data['aggregate_rating'].size)
    assert_equal('EXTERNAL KEY - rating_value', transformed_data['aggregate_rating'][0]['external_key'])
    assert_equal('123454321', transformed_data['aggregate_rating'][0]['id'].external_source_id)
    assert_equal('EXTERNAL KEY - rating_value', transformed_data['aggregate_rating'][0]['id'].external_key)
  end
end
