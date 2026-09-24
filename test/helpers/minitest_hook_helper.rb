# frozen_string_literal: true

require 'minitest/hooks'

module DataCycleCore
  module MinitestHookHelper
    extend ActiveSupport::Concern
    include Minitest::Hooks

    # Pristine snapshot of DataCycleCore.features, captured once at boot (see
    # test_helper.rb). Many tests mutate the *global* DataCycleCore.features in place
    # (e.g. `features[:serialize][:serializers][:asset] = true`) and rely on their own
    # teardown/after(:all) to put it back. Only the top-level hash is frozen
    # (lib/data_cycle_core.rb), so nested config is unprotected. Under parallel_tests
    # the files run in random order, so a single class that leaves the shared config
    # in a bad state (e.g. features[:serialize][:serializers] == nil) makes every
    # unrelated serialize/download test scheduled after it in the same worker crash
    # with `undefined method '[]=' for nil`. Restoring the snapshot after every test
    # class contains such leaks to the class that caused them.
    mattr_accessor :pristine_features

    class << self
      # Deep-copy the fully-loaded feature configuration. Called from test_helper.rb
      # right after the app boots, before any test has had a chance to mutate it.
      #
      # deep_dup stays indifferent only because of test_helper.rb's IndifferentDeepDup — see
      # the note there.
      def capture_pristine_features!
        self.pristine_features ||= DataCycleCore.features.deep_dup.freeze
      end

      # Restore the shared global config to the pristine snapshot and drop the
      # memoized per-feature configuration/enabled caches so a following class sees
      # a clean state regardless of what the previous class did to it.
      #
      # Frozen because the boot loader freezes the hash it installs (lib/data_cycle_core.rb),
      # and without this the suite ran unfrozen from the first test class onward. Like boot,
      # it protects the top level only — every mutation in the suite is nested
      # (`features[:serialize][:serializers][:asset] = true`). Tests that replace the config
      # wholesale go through the mattr writer rather than Hash#[]=, so they still work and
      # leave it unfrozen until the next reset.
      def reset_features!
        return if pristine_features.nil?

        DataCycleCore.features = pristine_features.deep_dup.freeze
        DataCycleCore.features.each_key { |feature| DataCycleCore::Feature[feature]&.reload }
      end

      # Opt-in polluter finder: with DC_TEST_FEATURE_GUARD set, log any class that
      # leaves DataCycleCore.features different from the pristine snapshot. Non-fatal
      # so it never turns a green run red; it just names the culprit in the log.
      def warn_on_feature_drift(context)
        return if pristine_features.nil? || DataCycleCore.features == pristine_features

        drifted = (pristine_features.keys | DataCycleCore.features.keys).reject do |k|
          pristine_features[k] == DataCycleCore.features[k]
        end
        warn "[feature-guard] #{context} left DataCycleCore.features drifted for: #{drifted.join(', ')}"
      end
    end

    included do
      around(:all) do |&block|
        # Restore the shared global DataCycleCore.features to its pristine snapshot at
        # the START of every test class (see the mattr_accessor comment above for why
        # this matters). This MUST live in around(:all), not before/after(:all):
        # minitest/hooks implements those via `define_method(:before_all/:after_all)`,
        # so the 306 subclasses that define their own before/after(:all) (every
        # integration test via ActionDispatchIntegrationTest, v4/base, ...) override a
        # same-named hook declared here and their `super` skips our block — the hook is
        # shadowed. around(:all) is inherited and never overridden by a subclass, so it
        # always runs first for each class and cannot be shadowed. Resetting on entry
        # (rather than in a trailing after(:all)) also survives a crashing after(:all)
        # in the class that polluted the config.
        DataCycleCore::MinitestHookHelper.reset_features!

        # Some before(:all) blocks upsert_all template schemas directly (bypassing the cache
        # invalidation the importer performs), so a ThingTemplate cache warmed by an earlier test
        # class would be stale for the content those blocks build. Reset before setup.
        DataCycleCore::ThingTemplate.reset_template_caches!

        ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
          super(&block)
        ensure
          DataCycleCore::MinitestHookHelper.warn_on_feature_drift(self.class.name) if ENV['DC_TEST_FEATURE_GUARD']
          raise ActiveRecord::Rollback
        end
      end

      # needed for config.active_job.queue_adapter = :test
      # backtrace for failures is not working correctly with this block
      # around do |&block|
      #   perform_enqueued_jobs do
      #     super(&block)
      #   end
      # end

      setup do
        instance_variables.each do |iv|
          tmp = instance_variable_get(iv)
          next unless tmp.is_a?(ApplicationRecord) && !tmp.new_record?

          tmp.instance_variable_set(:@destroyed, false) if tmp.destroyed?
          tmp.reload
        end
      end

      # Ensure any in-memory cache is cleared between tests so throttles and cached data do not leak between test cases.
      teardown do
        Rails.cache.clear if defined?(Rails) && Rails.cache.respond_to?(:clear)
      end
    end
  end
end
