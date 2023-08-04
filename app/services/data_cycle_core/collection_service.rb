# frozen_string_literal: true

module DataCycleCore
  module CollectionService
    class << self
      def to_select_option(collection, locale)
        DataCycleCore::Filter::SelectOption.new(
          collection['id'],
          collection['name'].presence || '__DELETED__',
          collection['class_name'],
          "#{I18n.t("activerecord.models.data_cycle_core/#{collection['class_name']}", count: 1, locale:)}: #{collection['name'].presence || '__DELETED__'}"
        )
      end
    end
  end
end
