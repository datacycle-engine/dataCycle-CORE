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
        push_config: {
        },
        refresh_config: {
        }
      }
    )
  end

  it 'produces a push_config' do
    assert(subject.push_config, subject.config['push_config'].symbolize_keys)
  end

  it 'returns nil if no push_config is defined' do
    subject.config = nil
    assert_nil(subject.push_config)
  end

  it 'produces a refresh_config' do
    assert(subject.refresh_config, subject.config['refresh_config'].symbolize_keys)
  end

  it 'returns nil if no refresh_config is defined' do
    subject.config = nil
    assert_nil(subject.refresh_config)
  end
end
