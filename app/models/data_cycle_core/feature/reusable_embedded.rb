# frozen_string_literal: true

module DataCycleCore
  module Feature
    # An embedded with the boolean flag (attribute_keys in features.yml) can be linked into a second
    # parent instead of being copied. Templates::Extensions::ReusableEmbedded adds the flag to every
    # embedded template while the feature is enabled, so a project only switches it on. What a
    # single thing answers (flagged? shared? parents) lives in Feature::Content::ReusableEmbedded.
    class ReusableEmbedded < Base
      class << self
        # @return [Module] adds #reusable?, #reusable_parents and #shared_embedded? to Thing
        def content_module
          DataCycleCore::Feature::Content::ReusableEmbedded
        end

        # @param template_names [String, Array<String>] the :template_name: of an embedded attribute
        # @return [Array<String>] the ones whose schema defines the flag
        def reusable_templates(template_names)
          return [] unless enabled?

          Array.wrap(template_names).select do |name|
            DataCycleCore::ThingTemplate.cached_by_template_name(name)&.schema&.dig('properties', primary_attribute_key).present?
          end
        end

        # Reads the flag from things.metadata rather than searches.advanced_attributes: the search
        # row is written by a job after the save, so a block flagged a moment ago would not be offered yet.
        # The content_type predicate is what lets Postgres use index_things_on_reusable_embedded, a
        # partial index over embedded rows; include_embedded alone adds no such predicate.
        #
        # @param query [DataCycleCore::Filter::Search]
        # @param content [DataCycleCore::Thing, nil] the content being edited; what it already embeds
        #   is linked and not offered again
        # @return [DataCycleCore::Filter::Search] narrowed to the flagged embedded
        def reusable_only(query, content = nil)
          query = query
            .where(content_type: 'embedded')
            .where(DataCycleCore::Thing.value_condition({ primary_attribute_key => 'true' }), 'true')
          return query if content.nil?

          query.where.not(id: content.content_content_a.select(:content_b_id))
        end

        # A copy (split-view import, unlink, duplicate) is rendered with the flag off: the original
        # stays the one to link, and a flagged twin would offer the same block twice.
        #
        # @param key [String] an attribute key of the copied embedded
        # @return [Boolean] whether the editor shows this attribute unset on a copy
        def reset_on_copy?(key)
          enabled? && key.to_s == primary_attribute_key
        end
      end
    end
  end
end
