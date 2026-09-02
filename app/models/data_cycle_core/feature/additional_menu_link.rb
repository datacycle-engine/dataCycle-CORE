# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Links configured under `:additional_menu_link:` in features.yml, rendered as their own section
    # of the sidebar menu. Meant for services that live outside dataCycle itself (Grafana, a
    # spreadsheet tool, a CMS), so a project can add them from its configuration instead of
    # overriding the sidebar template.
    class AdditionalMenuLink < Base
      class << self
        # Configured entries, in configuration order. Entries without a `:url:` are dropped rather
        # than rendered as dead links.
        #
        # @return [Array<DataCycleCore::AdditionalMenuLink>]
        def links
          return [] unless enabled?

          @links ||= (configuration[:links].presence || {}).filter_map do |key, link|
            next if link.blank? || link[:url].blank?

            DataCycleCore::AdditionalMenuLink.new(
              key.to_s,
              link[:url].to_s,
              link[:icon].presence || 'external-link',
              link[:permission].presence&.to_sym
            )
          end
        end

        # Base.reload clears only `@configuration` and `@enabled`, so the memoized links would
        # otherwise survive a configuration reload.
        #
        # @return [self]
        def reload
          remove_instance_variable(:@links) if instance_variable_defined?(:@links)
          super
        end
      end
    end
  end
end
