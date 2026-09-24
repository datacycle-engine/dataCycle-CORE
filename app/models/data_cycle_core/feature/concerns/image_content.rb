# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Concerns
      # Shared by the pixies that only make sense on an image: the annotation service is a vision
      # service, and neither a focus point nor an alt text has a meaning elsewhere.
      module ImageContent
        IMAGE_ASSET_TYPE = 'image'

        # #image_content? first, ahead of everything Base#allowed? asks: the wand's helper asks this
        # for every string and text attribute of every template, and on a non-image one -- a
        # Veranstaltung with 30 of them -- Base walks the schema for the configuration and again per
        # dependency, for an answer the memoized asset property settles on its own.
        #
        # @param content [DataCycleCore::Thing, nil] content or template thing being edited
        # @return [Boolean] whether the pixie may run for this content
        def allowed?(content = nil)
          (image_content?(content) && super).present?
        end

        # Decided from the template's asset property rather than from a template name list, so a
        # project's own image templates are covered too.
        #
        # @param content [DataCycleCore::Thing, nil]
        # @return [Boolean]
        def image_content?(content)
          asset_key = content.try(:asset_property_names)&.first
          return false if asset_key.blank?

          content.properties_for(asset_key)&.dig('asset_type') == IMAGE_ASSET_TYPE
        end

        # The URL the annotation service is asked to fetch, always derived here and never taken from
        # a request: a client-supplied URL would turn a suggestion endpoint into a fetch proxy.
        #
        # An imported image has no asset: Wikidata's and Canto's (#49225) Bild contents carry the
        # file's url instead, and asking the asset answers nil -- which made both wands fail with
        # "no data" on every imported image. The order is the computed ALT label's
        # (:parameters: [virtual_web_url, content_url] in datacycle-feature-embedding), so a wand
        # and a recompute of the same imported image read one annotation rather than paying twice.
        #
        # A url without a host is skipped rather than sent -- the service could never fetch it, and
        # the empty answer would be cached for three days. Asset#public_url always carries one now,
        # so what this still guards is an imported content whose own url property holds a
        # path-relative value (e.g. media/foo.jpg), which a source feed may deliver.
        #
        # @param content [DataCycleCore::Thing]
        # @param asset [DataCycleCore::Asset, nil]
        # @return [String, nil]
        def image_url(content, asset = nil)
          [asset&.public_url, content.try(:virtual_web_url), content.try(:content_url)]
            .detect { |url| url.to_s.start_with?('http') }
        end

        # The annotations of an embedding result. Not a Hash for any answer a pixie can read, so
        # every consumer is spared the type guard.
        #
        # @param result [Object] what Feature['Embedding'].embedding answered
        # @return [Hash]
        def annotation_data(result)
          data = result.to_h['data']

          data.is_a?(::Hash) ? data : {}
        end
      end
    end
  end
end
