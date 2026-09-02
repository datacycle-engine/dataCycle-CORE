# frozen_string_literal: true

module DataCycleCore
  # Doubles for the asset backed compute modules (Pdf, Video) and the
  # AssetPreviewUrlExtension they share: an asset whose file is (not) attached and
  # a content standing in for an asset template with a linked preview image.
  module AssetPreviewDoubleHelper
    def unattached_file_double
      Class.new { def attached? = false }.new
    end

    def unattached_asset_double
      struct_double(file: unattached_file_double)
    end

    # `raises: true` makes the variant processing fail the way a missing or corrupt
    # blob does, which the compute modules rescue into nil
    def attached_asset_double(url: 'https://cdn.test/preview.png', raises: false)
      preview = Object.new
      if raises
        preview.define_singleton_method(:processed) { raise ActiveStorage::FileNotFoundError }
      else
        processed = Object.new
        processed.define_singleton_method(:url) { url }
        preview.define_singleton_method(:processed) { processed }
      end

      file = Object.new
      file.define_singleton_method(:attached?) { true }
      file.define_singleton_method(:preview) { |_variation| preview }

      struct_double(file:)
    end

    def asset_content_double(asset_property_names: ['asset'], linked_property_names: ['thumbnail_image'])
      struct_double(
        asset_property_names:,
        linked_property_names:,
        external_source_id: nil,
        id: nil,
        translatable_property_names: []
      )
    end
  end
end

ActiveSupport.on_load(:active_support_test_case) { include DataCycleCore::AssetPreviewDoubleHelper }
