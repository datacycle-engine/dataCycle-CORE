# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Object do
  subject do
    DataCycleCore::MasterData::Validators::Object
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'greeting' => {
          'label' => 'test_string',
          'type' => 'string',
          'storage_location' => 'translated_value'
        },
        'anzahl' => {
          'label' => 'test_number',
          'type' => 'number',
          'storage_location' => 'translated_value'
        }
      }
    end

    let(:daterange_hash) do
      {
        'validity_period' => {
          'label' => 'Gültigkeitszeitraum',
          'type' => 'object',
          'storage_location' => 'value',
          'validations' => {
            'daterange' => {
              'from' => 'valid_from',
              'to' => 'valid_until'
            }
          },
          'properties' => {
            'valid_from' => {
              'label' => 'Gültigkeit',
              'type' => 'date',
              'storage_location' => 'value'
            },
            'valid_until' => {
              'label' => 'bis',
              'type' => 'date',
              'storage_location' => 'value'
            }
          }
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'works with a simple hash' do
      data_hash = { 'greeting' => 'Hello World!', 'anzahl' => 5 }
      validator = subject.new(data_hash, template_hash)
      assert_equal(no_error_hash, validator.error)
    end

    it 'errors out when a wrong type is given' do
      new_template_hash = template_hash.deep_dup
      new_template_hash['greeting']['type'] = 'wrong type'
      data_hash = { 'greeting' => 'Hello World!', 'anzahl' => 5 }
      validator = subject.new(data_hash, new_template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'ignores additional data given' do
      data_hash = { 'greeting' => 'Hello World!', 'anzahl' => 5, 'xxx' => 'xxx' }
      validator = subject.new(data_hash, template_hash)
      assert_equal(no_error_hash, validator.error)
    end

    it 'does not warn for missing data' do
      data_hash = { 'greeting' => 'Hello World!' }
      validator = subject.new(data_hash, template_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'produces an error when a object definition is missing' do
      new_template_hash = template_hash.deep_dup
      new_template_hash['anzahl']['type'] = 'object'
      data_hash = { 'greeting' => 'Hello World!', 'anzahl' => 5 }
      validator = subject.new(data_hash, new_template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'aggregates errors/warnings' do
      data_hash = { 'greeting' => ['test', 'test2'], 'anzahl' => '5' }
      validator = subject.new(data_hash, template_hash)
      assert_equal(2, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
      data_hash = { 'greeting' => nil, 'anzahl' => nil }
      validator = subject.new(data_hash, template_hash)
      assert_equal(0, validator.error[:error].size)
      # assert_equal(1, validator.error[:warning].size)
    end

    it 'successfully validates daterange with proper template and varying test-data' do
      data_hash = {
        'validity_period' => {
          'valid_from' => '2016-01-01',
          'valid_until' => '2017-01-01'
        }
      }
      validator = subject.new(data_hash, daterange_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)

      data_hash = {
        'validity_period' => {
          'valid_from' => '2017-01-01',
          'valid_until' => '2016-01-01'
        }
      }
      validator = subject.new(data_hash, daterange_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)

      data_hash = {
        'validity_period' => {
          'valid_from' => 'a',
          'valid_until' => 'b'
        }
      }
      validator = subject.new(data_hash, daterange_hash)
      assert_equal(3, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)

      data_hash = {
        'validity_period' => {
          'valid_from' => 'a',
          'valid_until' => '2017-01-01'
        }
      }
      validator = subject.new(data_hash, daterange_hash)
      assert_equal(2, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)

      data_hash = {
        'validity_period' => {
          'valid_from' => '',
          'valid_until' => '2017-01-01'
        }
      }
      validator = subject.new(data_hash, daterange_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)

      data_hash = {
        'validity_period' => {
          'valid_from' => '',
          'valid_until' => ''
        }
      }
      validator = subject.new(data_hash, daterange_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    # TODO: [patrick]: check if required
    # it 'validates daterange with faulty templates, appropriately' do
    #   data_hash = {
    #     'validity_period' => {
    #       'valid_from' => '2016-01-01',
    #       'valid_until' => '2017-01-01'
    #     }
    #   }
    #
    #   new_template_hash = daterange_hash.deep_dup
    #   new_template_hash['validity_period']['validations']['daterange']['from'] = 'from'
    #   validator = subject.new(data_hash, new_template_hash)
    #   assert_equal(1, validator.error[:error].size)
    #   assert_equal(0, validator.error[:warning].size)
    #
    #   new_template_hash = daterange_hash.deep_dup
    #   new_template_hash['validity_period']['validations']['daterange']['to'] = 'to'
    #   validator = subject.new(data_hash, new_template_hash)
    #   assert_equal(1, validator.error[:error].size)
    #   assert_equal(0, validator.error[:warning].size)
    #
    #   new_template_hash = daterange_hash.deep_dup
    #   new_template_hash['validity_period']['validations']['daterange'] = { 'from' => 'valid_from' }
    #   validator = subject.new(data_hash, new_template_hash)
    #   assert_equal(1, validator.error[:error].size)
    #   assert_equal(0, validator.error[:warning].size)
    #
    #   new_template_hash = daterange_hash.deep_dup
    #   new_template_hash['validity_period']['validations']['daterange'] = { 'to' => 'valid_until' }
    #   validator = subject.new(data_hash, new_template_hash)
    #   assert_equal(1, validator.error[:error].size)
    #   assert_equal(0, validator.error[:warning].size)
    #
    #   new_template_hash = daterange_hash.deep_dup
    #   new_template_hash['validity_period']['validations']['daterange'] = {}
    #   validator = subject.new(data_hash, new_template_hash)
    #   assert_equal(1, validator.error[:error].size)
    #   assert_equal(0, validator.error[:warning].size)
    #
    #   new_template_hash = daterange_hash.deep_dup
    #   new_template_hash['validity_period']['validations']['integerrange'] = { 'from' => 'valid_from', 'to' => 'valid_until' }
    #   new_template_hash['validity_period']['validations']['format'] = { 'from' => 'data_time' }
    #   validator = subject.new(data_hash, new_template_hash)
    #   assert_equal(0, validator.error[:error].size)
    #   assert_equal(2, validator.error[:warning]['validity_period'].size)
    # end

    it 'validates object daterange edge-cases correctly' do
      data_hash = {
        'validity_period' => {
          'valid_from' => '2016-01-01',
          'valid_until' => '2017-01-01'
        }
      }
      validator = subject.new(data_hash, daterange_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)

      validator = subject.new({}, daterange_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)

      validator = subject.new(nil, daterange_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)

      validator = subject.new({ 'test' => 'wrong' }, daterange_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'produced an error if wrong validator is given' do
      data_hash = {
        'validity_period' => {
          'valid_from' => '2016-01-01',
          'valid_until' => '2017-01-01'
        }
      }
      template_hash = daterange_hash.deep_dup
      template_hash['validity_period']['validations']['unknown_valitor'] = 'test'
      validator = subject.new(data_hash, template_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)

      template_hash = daterange_hash.deep_dup
      template_hash['validity_period']['validations']['daterange'] = { 'from' => 'valid_from' }
      validator = subject.new(data_hash, template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end
  end
end
