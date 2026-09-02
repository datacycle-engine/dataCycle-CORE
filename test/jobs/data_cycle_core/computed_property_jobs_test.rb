# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ComputedPropertyJobsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    UUID = '00000000-0000-0000-0000-000000000000'

    test 'compute_properties does nothing for blank keys' do
      assert_nil DataCycleCore::ComputePropertiesJob.perform_now(UUID, [])
    end

    test 'compute_properties updates the computed values for the given keys' do
      called = []
      thing = Object.new
      thing.define_singleton_method(:update_computed_values) { |keys:| called << keys }

      DataCycleCore::Thing.stub(:find, thing) do
        DataCycleCore::ComputePropertiesJob.perform_now(UUID, ['slug'])
      end

      assert_equal [['slug']], called
    end

    test 'compute_properties builds the concurrency key from id and keys' do
      job = DataCycleCore::ComputePropertiesJob.new(UUID, ['a', 'b'])

      assert_equal "DataCycleCore::ComputePropertiesJob/#{UUID}/a,b", job.concurrency_key
    end

    test 'update_async_computed_properties returns for blank keys' do
      assert_nil DataCycleCore::UpdateAsyncComputedPropertiesJob.perform_now(UUID, [])
    end

    test 'update_async_computed_properties returns when no key is async computed' do
      thing = Object.new
      thing.define_singleton_method(:async_computed_property_names) { ['async_key'] }

      thing.define_singleton_method(:update_computed_values_for_locale) { |**_| flunk('should not be called') }

      DataCycleCore::Thing.stub(:find, thing) do
        assert_nil DataCycleCore::UpdateAsyncComputedPropertiesJob.perform_now(UUID, ['other'])
      end
    end

    test 'update_async_computed_properties updates the intersecting async keys' do
      called = []
      thing = Object.new
      thing.define_singleton_method(:async_computed_property_names) { ['async_key'] }
      thing.define_singleton_method(:update_computed_values_for_locale) { |keys:, locale:| called << [keys, locale] }

      DataCycleCore::Thing.stub(:find, thing) do
        DataCycleCore::UpdateAsyncComputedPropertiesJob.perform_now(UUID, ['async_key'], 'de')
      end

      assert_equal [[['async_key'], 'de']], called
    end

    test 'update_async_computed_properties builds the concurrency key' do
      job = DataCycleCore::UpdateAsyncComputedPropertiesJob.new(UUID, ['a', 'b'], 'de')

      assert_equal "DataCycleCore::UpdateAsyncComputedPropertiesJob/#{UUID}/a,b/de", job.concurrency_key
      assert_equal 10, job.priority
    end

    test 'video_transcoding processes the video and stores the url' do
      stored = []
      thing = Object.new
      thing.define_singleton_method(:properties_for) { |_name| { 'compute' => { 'transformation' => { 'version' => 'preview' } } } }
      thing.define_singleton_method(:set_data_hash) { |data_hash:, update_computed:| stored << [data_hash, update_computed] }

      DataCycleCore::Feature::VideoTranscoding.stub(:process_video, 'https://example.com/video.mp4') do
        DataCycleCore::Thing.stub(:find, thing) do
          DataCycleCore::VideoTranscodingJob.perform_now(UUID, 'video_url')
        end
      end

      assert_equal [[{ 'video_url' => 'https://example.com/video.mp4' }, false]], stored
    end

    test 'video_transcoding builds the concurrency key from both arguments' do
      job = DataCycleCore::VideoTranscodingJob.new(UUID, 'video_url')

      assert_equal "DataCycleCore::VideoTranscodingJob/#{UUID}/video_url", job.concurrency_key
      assert_equal 12, job.priority
    end
  end
end
