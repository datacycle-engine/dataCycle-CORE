# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class AudioTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Audio
        end

        test 'meta_value reads a nested metadata path from the audio asset' do
          audio = struct_double(metadata: { 'audio_properties' => { 'length' => 123 } })

          DataCycleCore::Audio.stub(:find_by, audio) do
            assert_equal(123, subject.meta_value('audio-id', ['audio_properties', 'length']))
          end
        end

        test 'meta_value returns nil when the audio asset is missing' do
          DataCycleCore::Audio.stub(:find_by, nil) do
            assert_nil(subject.meta_value('missing-id', ['audio_properties', 'length']))
          end
        end

        test 'meta_value returns nil for a blank path' do
          audio = struct_double(metadata: { 'audio_properties' => { 'length' => 123 } })

          DataCycleCore::Audio.stub(:find_by, audio) do
            assert_nil(subject.meta_value('audio-id', nil))
          end
        end

        test 'duration converts the metadata length to a float' do
          audio = struct_double(metadata: { 'audio_properties' => { 'length' => 123 } })

          DataCycleCore::Audio.stub(:find_by, audio) do
            value = subject.duration(computed_parameters: { 'asset' => 'audio-id' }, data_hash: {}, key: 'duration', content: nil)

            assert_in_delta(123.0, value)
          end
        end
      end
    end
  end
end
