# frozen_string_literal: true

module DataCycleCore
  module CollectionService
    class << self
      def to_select_option(collection, locale)
        DataCycleCore::Filter::SelectOption.new(
          collection['id'],
          collection['name'],
          collection['class_name'],
          "#{I18n.t("activerecord.models.data_cycle_core/#{collection['class_name']}", count: 1, locale: locale)}: #{collection['name']}"
        )
      end
    end
  end
end
