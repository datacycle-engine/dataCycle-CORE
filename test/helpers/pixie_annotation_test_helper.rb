# frozen_string_literal: true

module DataCycleCore
  # Shared doubles of the pixie tests (#47879, #47881). All three of them stand the annotation
  # service in for itself: what is under test is the request an endpoint builds and the guards it
  # applies, never the service.
  module PixieAnnotationTestHelper
    # the real client is an XHR: without it a CanCan denial answers with an html redirect
    JSON_HEADERS = { 'ACCEPT' => 'application/json' }.freeze

    # Answers every annotation request with +data+ and records the arguments it was called with, so
    # a test can assert what the endpoint asked for -- and that a second endpoint asked identically,
    # which is what keeps both on one Feature::Embedding cache entry.
    #
    # @param data [Hash] the annotations to answer with
    # @return [Array<Hash>] one entry of keyword arguments per call, in call order
    def stub_embedding(data, &)
      calls = []
      DataCycleCore::Feature['Embedding'].stub(:embedding, lambda { |**kwargs|
        calls << kwargs
        { 'data' => data }
      }, &)
      calls
    end

    # The three pixies, disabled for the duration of the block, the way a project that merges the
    # feature without turning it on has them.
    #
    # The flags themselves are flipped rather than #allowed? being stubbed: what a rollout asks is
    # whether the surfaces around a pixie survive its :enabled: false, and #enabled? reads
    # DataCycleCore.features directly and memoizes what it found. Routes and the controller mixins
    # are wired at boot and deliberately stay -- an unconditional route that fails closed is part
    # of what this pins.
    #
    # @return [void]
    def with_pixies_disabled
      keys = [:annotation_pixie, :image_description_pixie, :classification_pixie]
      features = keys.map { |key| DataCycleCore::Feature[key.to_s.camelize] }
      original = DataCycleCore.features

      # the hash is frozen, so it is swapped rather than written into
      DataCycleCore.features = original.merge(
        keys.index_with { |key| original[key].merge('enabled' => false, 'allowed' => false) }
      )
      features.each(&:reload)

      yield
    ensure
      DataCycleCore.features = original if original
      features&.each(&:reload)
    end

    # @param with_asset [Boolean] whether the image carries an uploaded asset. Only the suggestion
    #   endpoints need one -- they derive the url they annotate from it -- so a test of the write
    #   paths saves the upload.
    def pixie_image(name, template_name: 'Bild', with_asset: true)
      data_hash = { name: }
      data_hash[:asset] = upload_image('test_rgb.jpeg').id if with_asset

      DataCycleCore::TestPreparations.create_content(template_name:, data_hash:)
    end
  end
end

ActiveSupport.on_load(:active_support_test_case) { include DataCycleCore::PixieAnnotationTestHelper }
