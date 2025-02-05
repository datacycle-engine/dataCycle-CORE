# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Validators::Oembed do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Validators::Oembed
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'oembed',
        'storage_location' => 'value'
      }
    end

    let(:required_template_hash) do
      {
        'label' => 'Test',
        'type' => 'oembed',
        'storage_location' => 'value',
        'validations' => { 'required' => true }
      }
    end

    let(:soft_required_template_hash) do
      {
        'label' => 'Test',
        'type' => 'oembed',
        'storage_location' => 'value',
        'validations' => { 'soft_required' => true }
      }
    end

    let(:url) do
      'https://www.youtube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl'
    end

    let(:no_error_hash) do
      { error: {}, warning: {}, result: {'' => ["https://www.youtube.com/oembed?url=#{url}"]} }
    end

    it 'error on blank url if validation is required:true' do
      validator = subject.new(nil, required_template_hash)
      assert_equal(1, validator.error[:error].size)
    end

    it 'warning on blank url if validation is soft_required:true' do
      validator = subject.new(nil, soft_required_template_hash)
      assert_equal(1, validator.error[:warning].size)
    end

    it 'no warning/error on blank url if validation is neither soft_required:true nor required:true' do
      validator = subject.new(nil, soft_required_template_hash)
      assert_equal(1, validator.error[:warning].size)
    end

    it 'works with a real values' do
      validator = subject.new(url, template_hash)
      assert_equal(no_error_hash, validator.error)
    end

    it 'error if invalid url' do
      validator = subject.new('ht//www.youtube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl', template_hash)
      assert_equal(1, validator.error[:error].size)
    end

    it 'error if valid url, but no url provider found' do
      validator = subject.new('http://www.you-tube.com/watch?v=AlGcVkVzxt0&t=1s&pp=ygUJZGF0YWN5Y2xl', template_hash)
      assert_equal(1, validator.error[:error].size)
    end
  end
end
