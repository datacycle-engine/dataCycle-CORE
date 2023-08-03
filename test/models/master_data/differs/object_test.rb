# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::Object do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Differs::Object
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

    let(:template_hash_deep) do
      {
        'greeting' => {
          'label' => 'test_string',
          'type' => 'string',
          'storage_location' => 'translated_value'
        },
        'range' => {
          'label' => 'egal',
          'type' => 'object',
          'storage_location' => 'tranlsated_value',
          'properties' => {
            'von' => {
              'label' => 'von',
              'type' => 'number',
              'storage_location' => 'translated_value'
            },
            'bis' => {
              'label' => 'bis',
              'type' => 'number',
              'storage_location' => 'translated_value'
            }
          }
        }
      }
    end

    let(:template_hash_deeper) do
      {
        'greeting' => {
          'label' => 'test_string',
          'type' => 'string',
          'storage_location' => 'translated_value'
        },
        'range' => {
          'label' => 'egal',
          'type' => 'object',
          'storage_location' => 'tranlsated_value',
          'properties' => {
            'von' => {
              'label' => 'von',
              'type' => 'number',
              'storage_location' => 'translated_value'
            },
            'bis' => {
              'label' => 'bis',
              'type' => 'number',
              'storage_location' => 'translated_value'
            },
            'descriptions' => {
              'lable' => 'descriptions',
              'type' => 'object',
              'storage_location' => 'translated_value',
              'properties' => {
                'text' => {
                  'label' => 'text',
                  'type' => 'string',
                  'storage_location' => 'translated_value'
                },
                'content' => {
                  'label' => 'text',
                  'type' => 'string',
                  'storage_location' => 'translated_value'
                }
              }
            }
          }
        }
      }
    end

    it 'works with a simple hash' do
      a = { 'greeting' => 'Hello World!', 'anzahl' => 5 }
      b = a
      diff_hash = subject.new(a, b, template_hash).diff_hash
      assert_equal({}, diff_hash)
    end

    it 'recognizes data with semanitally the same data as equal' do
      a = { 'greeting' => 'Hello World!', 'anzahl' => 5 }
      b_data = [
        { 'greeting' => 'Hello World!', 'anzahl' => '5' },
        { 'greeting' => 'Hello World!', 'anzahl' => 5.0 },
        { 'greeting' => 'Hello World!', 'anzahl' => '5.0' },
        { 'greeting' => 'Hello World!', 'anzahl' => 5.0001 },
        { 'greeting' => 'Hello World!', 'anzahl' => '5.0001' }
      ]
      b_data.each do |b|
        diff_hash = subject.new(a, b, template_hash).diff_hash
        assert_equal({}, diff_hash)
      end
    end

    it 'recognizes if greeting is changed' do
      a = { 'greeting' => 'Hello World!', 'anzahl' => 5 }
      b = { 'greeting' => 'Servas olter', 'anzahl' => 5 }
      diff_hash = subject.new(a, b, template_hash).diff_hash
      assert_equal({ 'greeting' => ['~', 'Hello World!', 'Servas olter'] }, diff_hash)
    end

    it 'recognizes if greeting and number are changed' do
      a = { 'greeting' => 'Hello World!', 'anzahl' => 5 }
      b = { 'greeting' => 'Servas!', 'anzahl' => '10.0' }
      diff_hash = subject.new(a, b, template_hash).diff_hash
      assert_equal(
        {
          'greeting' => ['~', 'Hello World!', 'Servas!'],
          'anzahl' => ['~', 5, 10]
        },
        diff_hash
      )
    end

    it 'recognizes two hashes with included objects that are the same as equal' do
      a = { 'greeting' => 'servas', 'range' => { 'von' => 1, 'bis' => 100 } }
      b = a
      diff_hash = subject.new(a, b, template_hash_deep).diff_hash
      assert_equal({}, diff_hash)
    end

    it 'recognizes the differenece of two hashes with included objects' do
      a = { 'greeting' => 'servas', 'range' => { 'von' => 1, 'bis' => 100 } }
      b = { 'greeting' => 'servas', 'range' => { 'von' => 0, 'bis' => 99 } }
      diff_hash = subject.new(a, b, template_hash_deep).diff_hash
      assert_equal({ 'range' => { 'von' => ['~', 1, 0], 'bis' => ['~', 100, 99] } }, diff_hash)
    end

    it 'ignores blank objects' do
      a = { 'greeting' => 'servas', 'range' => { 'von' => nil, 'bis' => nil } }
      b = { 'greeting' => 'servas' }
      diff_hash = subject.new(a, b, template_hash_deep).diff_hash
      assert_equal({}, diff_hash)
    end

    it 'ignores blank branches' do
      a = { 'greeting' => 'servas', 'range' => { 'von' => nil, 'bis' => nil, 'descriptions' => { 'text' => '', 'content' => '' } } }
      b = { 'greeting' => 'servas' }
      diff_hash = subject.new(a, b, template_hash_deeper).diff_hash
      assert_equal({}, diff_hash)
    end
  end
end
