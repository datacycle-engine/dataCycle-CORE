# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Test stand-in for the embedding backend feature (plugin gem datacycle-feature-embedding), which
    # is not loaded in data-cycle-core's standalone test environment. See ContentClassifier for why
    # the stand-in has to be a boot-time constant rather than a definition inside a test file.
    #
    # Only the surface the pixies use is declared: .embedding is what the suggestion endpoints call
    # and what the tests stub per case; answering with an empty annotation by default keeps an
    # unstubbed call harmless instead of reaching for a network.
    class Embedding < Base
      class << self
        # @param image_url [String, nil] publicly reachable image URL
        # @return [Hash, nil] normalized annotation payload, shaped like the real feature's
        def embedding(image_url: nil, **)
          return if image_url.blank?

          { 'embedding' => [], 'dimensions' => 0, 'data' => {} }
        end

        # The annotation kept on a content's embedding row, which the suggestion endpoints read
        # before asking the service. Nothing is stored in this environment -- the embeddings table
        # belongs to the plugin gem -- so the default answer is none and a test that needs one
        # stubs this.
        #
        # @return [Hash, nil]
        def stored_annotation(_content)
          nil
        end
      end
    end
  end
end
