# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AutoTranslationJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'does nothing when the feature is disabled' do
      DataCycleCore::Feature::AutoTranslation.stub(:enabled?, false) do
        assert_nil DataCycleCore::AutoTranslationJob.perform_now('00000000-0000-0000-0000-000000000000', 'de')
      end
    end

    test 'translates the thing when the feature is enabled' do
      called = []
      thing = Object.new
      thing.define_singleton_method(:create_update_translations) { called << :translations }
      thing.define_singleton_method(:create_update_auto_translations) { called << :auto_translations }

      DataCycleCore::Feature::AutoTranslation.stub(:enabled?, true) do
        DataCycleCore::Thing.stub(:find_by, thing) do
          DataCycleCore::AutoTranslationJob.perform_now('00000000-0000-0000-0000-000000000000', 'de')
        end
      end

      assert_equal [:translations, :auto_translations], called
    end

    test 'exposes its concurrency key and priority' do
      job = DataCycleCore::AutoTranslationJob.new('abc', 'de')

      assert_equal 'DataCycleCore::AutoTranslationJob/abc', job.concurrency_key
      assert_equal 5, job.priority
    end
  end
end
