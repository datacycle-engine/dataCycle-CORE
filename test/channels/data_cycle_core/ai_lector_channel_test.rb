# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AiLectorChannelTest < ActionCable::Channel::TestCase
    tests DataCycleCore::AiLectorChannel

    # The AiLector feature lives in a separate gem that is not loaded in the
    # core dummy app, so DataCycleCore::Feature['AiLector'] returns nil here.
    # We stub Feature.[] to return a configurable fake feature.
    def fake_feature(enabled: true, lector: nil)
      feature = Object.new
      feature.define_singleton_method(:enabled?) { enabled }
      feature.define_singleton_method(:new) { |*_args, **_kwargs| lector }
      feature
    end

    def with_feature(feature, &)
      DataCycleCore::Feature.stub(:[], feature, &)
    end

    def valid_payload(overrides = {})
      {
        'template_name' => 'POI',
        'key' => 'name',
        'tip_key' => 'spelling',
        'identifier' => 'id-1',
        'stream_id' => 'stream-1'
      }.merge(overrides)
    end

    def subscribe_channel(user, feature = fake_feature)
      with_feature(feature) do
        stub_connection current_user: user
        subscribe window_id: 'win-1'
      end
    end

    def capture_broadcasts(&)
      broadcasts = []
      ActionCable.server.stub(:broadcast, ->(name, data) { broadcasts << [name, data] }, &)
      broadcasts
    end

    test 'subscribes and streams when feature enabled and user present' do
      subscribe_channel(User.find_by(email: 'admin@datacycle.at'))

      assert_predicate subscription, :confirmed?
      assert_has_stream 'ai_lector_win-1'
    end

    test 'rejects when the feature is disabled' do
      subscribe_channel(User.find_by(email: 'admin@datacycle.at'), fake_feature(enabled: false))

      assert_predicate subscription, :rejected?
    end

    test 'rejects without a current_user' do
      subscribe_channel(nil)

      assert_predicate subscription, :rejected?
    end

    test 'receive broadcasts a warning when the text is blank' do
      subscribe_channel(User.find_by(email: 'admin@datacycle.at'))

      broadcasts = capture_broadcasts { subscription.receive(valid_payload) }

      assert_equal 1, broadcasts.size
      assert_equal 'ai_lector_win-1', broadcasts.first[0]
      assert_predicate broadcasts.first[1][:warning], :present?
    end

    test 'receive streams chunks and a finished message on success' do
      lector = Object.new
      lector.define_singleton_method(:get_data) do |&block|
        block.call({ chunk: 'partial' })
        { text: 'done' }
      end
      feature = fake_feature(lector:)
      subscribe_channel(User.find_by(email: 'admin@datacycle.at'), feature)

      broadcasts = with_feature(feature) do
        capture_broadcasts { subscription.receive(valid_payload('text' => 'fix this')) }
      end

      assert(broadcasts.any? { |_, d| d[:chunk] == 'partial' })
      assert(broadcasts.any? { |_, d| d[:finished] })
    end

    test 'receive broadcasts a generic error for unexpected failures' do
      lector = Object.new
      lector.define_singleton_method(:get_data) { raise StandardError, 'boom' }
      feature = fake_feature(lector:)
      subscribe_channel(User.find_by(email: 'admin@datacycle.at'), feature)

      broadcasts = with_feature(feature) do
        capture_broadcasts { subscription.receive(valid_payload('text' => 'fix this')) }
      end

      assert(broadcasts.any? { |_, d| d[:error].present? })
    end

    test 'receive broadcasts a connection error for faraday failures' do
      lector = Object.new
      lector.define_singleton_method(:get_data) { raise Faraday::ConnectionFailed, 'no connection' }
      feature = fake_feature(lector:)
      subscribe_channel(User.find_by(email: 'admin@datacycle.at'), feature)

      broadcasts = with_feature(feature) do
        capture_broadcasts { subscription.receive(valid_payload('text' => 'fix this')) }
      end

      assert(broadcasts.any? { |_, d| d[:error].present? })
    end

    test 'receive includes the backtrace in development' do
      lector = Object.new
      lector.define_singleton_method(:get_data) { raise StandardError, 'boom' }
      feature = fake_feature(lector:)
      subscribe_channel(User.find_by(email: 'admin@datacycle.at'), feature)

      broadcasts = Rails.stub(:env, ActiveSupport::StringInquirer.new('development')) do
        with_feature(feature) do
          capture_broadcasts { subscription.receive(valid_payload('text' => 'fix this')) }
        end
      end

      assert(broadcasts.any? { |_, d| d[:error].to_s.include?('boom') })
    end

    test 'receive broadcasts an error when the payload is invalid' do
      subscribe_channel(User.find_by(email: 'admin@datacycle.at'))

      broadcasts = capture_broadcasts { subscription.receive({ 'identifier' => 'id-1' }) }

      assert(broadcasts.any? { |_, d| d[:error].present? })
    end
  end
end
