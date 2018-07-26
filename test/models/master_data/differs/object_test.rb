# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::Object do
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
  end
end
