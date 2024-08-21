# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::Oembed do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Differs::Oembed
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'oembed',
        'storage_location' => 'value'
      }
    end

    it 'recognizes equal urls' do
      assert_nil(subject.new('https://www.youtube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl', 'https://www.youtube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl').diff_hash)
    end

    it 'recognizes different urls' do
      assert_equal('~', subject.new('https://www.youtube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl', 'https://vimeo.com/226053498').diff_hash[0])
    end
  end
end
