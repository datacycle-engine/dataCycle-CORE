# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # The helper replaces I18n.reload!, which permanently dropped the dry-validation error texts
  # injected at boot and so killed an arbitrary later API test in the same worker. Untested, the
  # replacement would rest on no more evidence than what it replaces — so this test asserts both
  # directions: that the stub takes effect AND that the exact prior state is back afterwards.
  class I18nTestHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include DataCycleCore::I18nTestHelper

    STUBBED_KEY = 'i18n_test_helper_test.stubbed.description'
    # The key the original failure hung on: injected by dry-schema at boot, present in no file
    # from I18n.load_path.
    BOOT_INJECTED_KEY = 'dry_validation.errors.filled?'

    test 'stored translations apply inside the block and are gone afterwards' do
      assert_nil I18n.t(STUBBED_KEY, default: nil)

      with_stored_translations({ i18n_test_helper_test: { stubbed: { description: 'gestubbt' } } }) do
        I18n.available_locales.each { |locale| assert_equal 'gestubbt', I18n.t(STUBBED_KEY, locale:) }
      end

      assert_nil I18n.t(STUBBED_KEY, default: nil), 'the stub outlived the block and leaks into every following test'
    end

    # The actual guarantee: unlike I18n.reload!, the helper must lose NOTHING that did not come
    # from I18n.load_path.
    test 'restoring keeps the boot-injected messages that I18n.reload! would destroy' do
      before = I18n.t(BOOT_INJECTED_KEY, locale: :en, default: nil)

      assert_predicate before, :present?, 'test precondition: the base error texts are loaded'

      with_stored_translations({ i18n_test_helper_test: { stubbed: { description: 'gestubbt' } } }) { nil }

      assert_equal before, I18n.t(BOOT_INJECTED_KEY, locale: :en, default: nil)
    end

    # The block must not keep the state even when it raises — otherwise the pollution rides on a
    # failing test and travels through the rest of the worker.
    test 'the state is restored even when the block raises' do
      assert_raises(RuntimeError) do
        with_stored_translations({ i18n_test_helper_test: { stubbed: { description: 'gestubbt' } } }) do
          raise 'boom'
        end
      end

      assert_nil I18n.t(STUBBED_KEY, default: nil)
      assert_predicate I18n.t(BOOT_INJECTED_KEY, locale: :en, default: nil), :present?
    end

    test 'snapshot and restore work as a pair for setup/teardown style tests' do
      snapshot_translations!
      I18n.backend.store_translations(I18n.locale, { i18n_test_helper_test: { stubbed: { description: 'gestubbt' } } })

      assert_equal 'gestubbt', I18n.t(STUBBED_KEY)

      restore_translations!

      assert_nil I18n.t(STUBBED_KEY, default: nil)
    end
  end
end
