# frozen_string_literal: true

module DataCycleCore
  # A local oEmbed provider for tests that save an oembed property, whose validator resolves the
  # url against a provider list. Without this the resolution reads
  # https://oembed.com/providers.json over the network, and that list is a moving target (Vimeo was
  # removed from it), so a test pinned to one of its entries fails when the entry disappears.
  module OembedProviderHelper
    TEST_OEMBED_PROVIDER_URL = 'https://provider.test'
    TEST_OEMBED_URL = "#{TEST_OEMBED_PROVIDER_URL}/watch?v=1".freeze

    def with_test_oembed_provider(&)
      provider = {
        'provider_name' => 'Test Provider',
        'provider_url' => TEST_OEMBED_PROVIDER_URL,
        'endpoints' => [{
          'schemes' => ["#{TEST_OEMBED_PROVIDER_URL}/*"],
          'url' => "#{TEST_OEMBED_PROVIDER_URL}/oembed.{format}",
          'formats' => ['json']
        }]
      }
      config = { 'base_json' => 'https://providers.test/list.json', 'oembed_providers' => [provider] }

      DataCycleCore.stub(:oembed_providers, config) do
        Rails.cache.delete(config['base_json'])

        Net::HTTP.stub(:get, [].to_json, &)
      end
    end
  end
end

ActiveSupport.on_load(:active_support_test_case) { include DataCycleCore::OembedProviderHelper }
