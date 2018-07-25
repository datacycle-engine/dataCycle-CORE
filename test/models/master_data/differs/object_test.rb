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
      diff_hash = subject.new(a, b, template_hash)
      assert_equal(0, diff_hash.size)
    end
  end
end
