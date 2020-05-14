# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::ExternalSystem do
  subject do
    DataCycleCore::ExternalSystem.new(
      name: 'System Test',
      credentials: {
        host: 'https://test/',
        key: 'testkey'
      },
      config: {
        export_config: {
        },
        refresh_config: {
        }
      }
    )
  end

  it 'produces a export_config' do
    assert(subject.export_config, subject.config['export_config'].symbolize_keys)
  end

  it 'returns nil if no export_config is defined' do
    subject.config = nil
    assert_nil(subject.export_config)
  end

  it 'produces a refresh_config' do
    assert(subject.refresh_config, subject.config['refresh_config'].symbolize_keys)
  end

  it 'returns nil if no refresh_config is defined' do
    subject.config = nil
    assert_nil(subject.refresh_config)
  end
end
