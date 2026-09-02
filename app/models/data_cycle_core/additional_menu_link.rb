# frozen_string_literal: true

module DataCycleCore
  # A single link configured under `:additional_menu_link:` in features.yml and rendered in its own
  # sidebar menu section. Instances are the CanCan subject of
  # Abilities::Segments::AdditionalMenuLinkByKeys, so visibility is decided per link.
  AdditionalMenuLink = Struct.new(:key, :url, :icon, :permission) do
    # @return [String] label from `data_cycle_core.additional_menu_links.<key>`, falling back to the
    #   humanized configuration key
    def title(locale = nil)
      I18n.t("data_cycle_core.additional_menu_links.#{key}", locale:, default: key.humanize)
    end

    # @return [String] font-awesome classes for `:icon:`, which is configured without the `fa-` prefix
    def icon_class
      "fa fa-#{icon}"
    end

    # Whether `:url:` names another host and must therefore be linked verbatim, rather than being
    # resolved below the application's `root_path`.
    #
    # @return [Boolean]
    def external?
      url.to_s.start_with?('//') || url.to_s.match?(%r{\A[a-z][a-z0-9+.-]*://}i)
    end

    # ActiveModel::Name#human returns a hard-coded English name for a plain Struct, whose i18n_scope
    # is empty, so translation goes through DataAttributeModel instead.
    #
    # @return [DataCycleCore::DataAttributeModel]
    def self.model_name
      @model_name ||= DataCycleCore::DataAttributeModel.new(self)
    end
  end
end
