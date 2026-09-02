# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Keeps a content translated into the same locales as the contents it links to. Opted into per
    # linked property (`:features: {:locale_inheritance: {:allowed: true}}`), for templates whose
    # translated values are computed from a link and therefore have nothing to translate by hand.
    class LocaleInheritance < Base
      class << self
        # @return [Module] hooks prepended to DataCycleCore::Content::DataHash
        def data_hash_module
          DataCycleCore::Feature::DataHash::LocaleInheritance
        end

        # Linked properties opting into locale inheritance. Read from thing_templates rather than
        # the content_properties materialized view, which would report the state of the last
        # refresh instead of the current templates. Cached, as every save that creates a
        # translation asks for it.
        #
        # @return [Hash{String => Array<String>}] property names keyed by template name
        def inheriting_properties
          DataCycleCore::ThingTemplate.cached_schema_scan(:locale_inheritance_properties) do
            sql = <<~SQL.squish
              SELECT thing_templates.template_name, properties.key
              FROM thing_templates
                CROSS JOIN LATERAL jsonb_each(thing_templates.schema -> 'properties') properties(key, value)
              WHERE properties.value -> 'features' -> ? ->> 'allowed' = 'true'
                AND properties.value ->> 'type' = 'linked'
            SQL

            ActiveRecord::Base.connection
              .select_rows(ActiveRecord::Base.send(:sanitize_sql_array, [sql, feature_key]))
              .group_by(&:first)
              .transform_values { |v| v.map(&:second) }
          end
        end

        # Things that link to +content+ through a property inheriting its locales. Filtering by
        # (template_name, relation) in SQL keeps a widely linked content from loading every
        # linking thing just to test the feature on it. Embedded templates opting in are excluded
        # rather than loaded and skipped by #inherit_missing_locales — an embedded content is
        # written through its parent, never on its own.
        #
        # @param content [DataCycleCore::Thing] the linked content whose locales are inherited
        # @return [ActiveRecord::Relation]
        def inheriting_things(content)
          properties = inheriting_properties
          return DataCycleCore::Thing.none if properties.blank?

          things = DataCycleCore::Thing.arel_table
          links = DataCycleCore::ContentContent::Link.arel_table

          DataCycleCore::Thing
            .without_embedded
            .joins(:content_content_links_a)
            .where(content_content_links: { content_b_id: content.id })
            .where(properties.map { |template_name, keys| things[:template_name].eq(template_name).and(links[:relation].in(keys)) }.reduce(:or))
            .distinct
        end
      end
    end
  end
end
