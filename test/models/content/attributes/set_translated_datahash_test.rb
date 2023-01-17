# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    module Attributes
      class SetTranslatedDatahashTest < ActiveSupport::TestCase
        setup do
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Service', data_hash: { name: 'Test Service 1' })
          @content_with_embedded = DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: { name: 'Test Event 1' })
        end

        test 'change name with different available ways' do
          @content.set_data_hash_with_translations(data_hash: { name: 'Test Service 2' }, partial_update: true)
          assert_equal('Test Service 2', @content.name)
          assert_equal(1, @content.available_locales.size)

          @content.set_data_hash_with_translations(data_hash: { datahash: { name: 'Test Service 3' } }, partial_update: true)
          assert_equal('Test Service 3', @content.name)
          assert_equal(1, @content.available_locales.size)

          @content.set_data_hash_with_translations(data_hash: { translations: { de: { name: 'Test Service 4' } } }, partial_update: true)
          assert_equal('Test Service 4', @content.name)
          assert_equal(1, @content.available_locales.size)
        end

        test 'change name in another language with different available ways' do
          I18n.with_locale(:en) { @content.set_data_hash_with_translations(data_hash: { name: 'Test Service 2' }, partial_update: true) }
          assert_equal('Test Service 1', @content.name)
          assert_equal('Test Service 2', I18n.with_locale(:en) { @content.name })
          assert_equal(2, @content.available_locales.size)

          I18n.with_locale(:en) { @content.set_data_hash_with_translations(data_hash: { datahash: { name: 'Test Service 3' } }, partial_update: true) }
          assert_equal('Test Service 1', @content.name)
          assert_equal('Test Service 3', I18n.with_locale(:en) { @content.name })
          assert_equal(2, @content.available_locales.size)

          @content.set_data_hash_with_translations(data_hash: { translations: { en: { name: 'Test Service 4' } } }, partial_update: true)
          assert_equal('Test Service 1', @content.name)
          assert_equal('Test Service 4', I18n.with_locale(:en) { @content.name })
          assert_equal(2, @content.available_locales.size)
        end

        test 'change name in multiple languages (wrong way)' do
          @content.set_data_hash_with_translations(data_hash: { datahash: { name: 'Test Service 2' }, translations: { en: { name: 'Test Service 3' } } }, partial_update: true)
          assert_equal('Test Service 1', @content.name)
          assert_equal('Test Service 3', I18n.with_locale(:en) { @content.name })
          assert_equal(2, @content.available_locales.size)
        end

        test 'change name in multiple languages' do
          @content.set_data_hash_with_translations(data_hash: { translations: { de: { name: 'Test Service 4' }, en: { name: 'Test Service 5' } } }, partial_update: true)
          assert_equal('Test Service 4', @content.name)
          assert_equal('Test Service 5', I18n.with_locale(:en) { @content.name })
          assert_equal(2, @content.available_locales.size)
        end

        test 'update translated embedded with datahash' do
          @content.set_data_hash_with_translations(data_hash: {
            datahash: { offers: [{ name: 'Test Offer 1' }] },
            translations: { de: { name: 'Test Service 4' } }
          }, partial_update: true)
          assert_equal('Test Service 4', @content.name)
          assert_equal('Test Offer 1', @content.offers.first.name)
          assert_equal(1, @content.available_locales.size)
        end

        test 'update translated embedded with nested datahash' do
          @content.set_data_hash_with_translations(data_hash: {
            datahash: { offers: [{ datahash: { name: 'Test Offer 1' } }] },
            translations: { de: { name: 'Test Service 4' } }
          }, partial_update: true)
          assert_equal('Test Service 4', @content.name)
          assert_equal('Test Offer 1', @content.offers.first.name)
          assert_equal(1, @content.offers.size)
          assert_equal(1, @content.available_locales.size)
        end

        test 'update translated embedded with nested translations hash' do
          @content.set_data_hash_with_translations(data_hash: {
            datahash: { offers: [{ translations: { de: { name: 'Test Offer 1' }, en: { name: 'Test Offer 2' } } }] },
            translations: { de: { name: 'Test Service 4' } }
          }, partial_update: true)
          assert_equal('Test Service 4', @content.name)
          assert_equal('Test Offer 1', @content.offers.first.name)
          assert_equal('Test Offer 2', I18n.with_locale(:en) { @content.offers.first.name })
          assert_equal(1, @content.offers.size)
          assert_equal(2, @content.offers.first.available_locales.size)
          assert_equal(1, @content.available_locales.size)
        end

        test 'update translated embedded with translations hash (wrong way)' do
          @content.set_data_hash_with_translations(data_hash: {
            translations: {
              de: { name: 'Test Service 4', offers: [{ name: 'Test Offer 1' }] },
              en: { offers: [{ name: 'Test Offer 2' }] }
            }
          }, partial_update: true)
          assert_equal('Test Service 4', @content.name)
          assert_nil(@content.offers.first.name)
          assert_equal('Test Offer 2', I18n.with_locale(:en) { @content.offers.first.name })
          assert_equal(1, @content.offers.size)
          assert_equal(1, @content.offers.first.available_locales.size)
          assert_equal(2, @content.available_locales.size)
        end

        test 'update non-translated embedded' do
          @content_with_embedded.set_data_hash_with_translations(data_hash: {
            datahash: {
              virtual_location: [{ name: 'Test Offer 1' }]
            }
          }, partial_update: true)
          assert_equal('Test Offer 1', @content_with_embedded.virtual_location.first.name)
          assert_equal(1, @content_with_embedded.virtual_location.size)
          assert_equal(1, @content_with_embedded.virtual_location.first.available_locales.size)
          assert_equal(1, @content_with_embedded.available_locales.size)
        end

        test 'update non-translated embedded in translations hash' do
          @content_with_embedded.set_data_hash_with_translations(data_hash: {
            translations: {
              de: { virtual_location: [{ name: 'Test Offer 1' }] },
              en: { virtual_location: [{ name: 'Test Offer 2' }] }
            }
          }, partial_update: true)

          I18n.with_locale(:en) do
            assert_equal('Test Offer 2', @content_with_embedded.virtual_location.first.name)
            assert_equal(1, @content_with_embedded.virtual_location.size)
            assert_equal(1, @content_with_embedded.virtual_location.first.available_locales.size)
          end

          assert_equal('Test Offer 1', @content_with_embedded.virtual_location.first.name)
          assert_equal(1, @content_with_embedded.virtual_location.size)
          assert_equal(1, @content_with_embedded.virtual_location.first.available_locales.size)
          assert_equal(2, @content_with_embedded.available_locales.size)
        end
      end
    end
  end
end
