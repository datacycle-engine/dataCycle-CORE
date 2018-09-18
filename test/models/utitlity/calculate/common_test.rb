# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Utility::Calculate::Common do
  subject do
    DataCycleCore::Utility::Calculate::Common
  end

  describe 'testing Common method: copy' do
    it 'copy string value' do
      assert_equal('test', subject.copy('test'))
    end

    it 'copy empty string value' do
      assert_equal('', subject.copy(''))
    end

    it 'copy nil value' do
      assert_nil(subject.copy(nil))
    end
  end
end
