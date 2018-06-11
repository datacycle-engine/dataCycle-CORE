# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::String do
  subject do
    DataCycleCore::MasterData::Validators::String
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'string',
        'storage_location' => 'translated_value'
      }
    end

    let(:complex_template_hash) do
      {
        'label' => 'Test',
        'type' => 'string',
        'storage_location' => 'translated_value',
        'validations' => {
          'min' => 20,
          'max' => 40,
          'pattern' => '/[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/',
          'format' => 'uuid'
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'works with a string' do
      validator = subject.new('test-string', template_hash)
      assert_equal(no_error_hash, validator.error)
    end

    it 'errors with wrong data' do
      validator = subject.new(10, template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'warns when no data is given' do
      validator = subject.new(nil, template_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(1, validator.error[:warning].size)
    end

    it 'works when complex format restrictions are satisfied' do
      validator = subject.new('0001824b-3e51-499c-a088-02db5b5e5cf7', complex_template_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when string is not long enough' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'min' => 3 } })
      validator = subject.new('x', new_template)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when string is too long' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'max' => 3 } })
      validator = subject.new('xxxx', new_template)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when string does not meet the pattern restriction' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'pattern' => '/[0-9a-f]{4}-[0-9a-f]{4}/' } })
      validator = subject.new('g111-1111', new_template)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
      validator = subject.new('f111-111', new_template)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'passes string does meet the pattern restriction' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'pattern' => '/[0-9a-f]{4}-[0-9a-f]{4}/' } })
      validator = subject.new('f111-1111', new_template)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when format is not supported' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'format' => 'xxx' } })
      validator = subject.new('test', new_template)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when string does not fulfill uuid format restriction' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'format' => 'uuid' } })
      validator = subject.new('test', new_template)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'works if string is a valid uuid' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'format' => 'uuid' } })
      validator = subject.new('0001824b-3e51-499c-a088-02db5b5e5cf7', new_template)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out when string does not fulfill url format restriction' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'format' => 'url' } })
      cases = ['!test', 'test/franz', 'html://test/franz', 'httpx://test/franz', 'http://test.com/franz:aöslkfj', 8, :test]
      cases.each do |test_case|
        validator = subject.new(test_case, new_template)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'passes when string fulfills url restriction' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'format' => 'url' } })
      cases = ['http://www.example.com', 'https://www.example.com', 'http://www.example.com/xxx/yyy', 'http://www.example.com/xxx?test=hallo', 'http://test.com/franz:3000']
      cases.each do |test_case|
        validator = subject.new(test_case, new_template)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'fails to recognize the following cases as errors' do
      new_template = template_hash.deep_dup.merge({ 'validations' => { 'format' => 'url' } })
      cases = ['https://www.....example.com', 'http://test.com/franz:99999999999999999']
      cases.each do |test_case|
        validator = subject.new(test_case, new_template)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end
  end
end
