# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Aggregate < Base
      AGGREGATE_TYPES = ['default', 'aggregate', 'belongs_to_aggregate'].freeze

      class << self
        def data_hash_module
          DataCycleCore::Feature::DataHash::Aggregate
        end

        def content_module
          DataCycleCore::Feature::Content::Aggregate
        end

        def aggregate?(content = nil)
          enabled? && !!configuration(content)['aggregate']
        end

        def aggregate_type_options(locale:)
          AGGREGATE_TYPES.map { |type| [I18n.t("feature.aggregate.types.#{type}", locale:), type] }
        end

        def aggregate_type_values(value:, locale:)
          aggregate_type_options(locale:).to_h.invert.values_at(*Array.wrap(value))
        end
      end
    end
  end
end
