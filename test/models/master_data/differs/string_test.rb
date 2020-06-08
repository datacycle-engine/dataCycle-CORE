# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::String do
  subject do
    DataCycleCore::MasterData::Differs::String
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'string',
        'storage_location' => 'column'
      }
    end

    it 'recognizes equal strings' do
      assert_nil(subject.new('test', 'test').diff_hash)
    end

    it 'recognizes equivalent unicode strings' do
      a = "Henry\u2163"
      b = 'HenryIV'
      assert_equal('~', subject.new(a, b).diff_hash[0])
    end

    it 'handles default_values correctly' do
      string = 'Hallo'
      hash = template_hash.deep_dup
      hash['default_value'] = string
      [[nil, string], [string, nil], [nil, nil]].each do |a, b|
        assert_nil(subject.new(a, b, hash).diff_hash)
      end
    end

    it 'handles eval default_values correctly' do
      string = 'Hello World'
      hash = template_hash.deep_dup
      hash['default_value'] = '{{ ["Hello", "World"].join(" ") }}'
      [[nil, string], [string, nil], [nil, nil]].each do |a, b|
        assert_nil(subject.new(a, b, hash).diff_hash)
      end
    end
  end
end
