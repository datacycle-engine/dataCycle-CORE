# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module Aggregate
        def external_syncs_as_property_values
          return super unless aggregate_type_aggregate?

          send(MasterData::Templates::AggregateTemplate::AGGREGATE_PROPERTY_NAME).flat_map(&:external_syncs_as_property_values).uniq
        end

        def base_template_name
          return super unless aggregate_type_aggregate?

          template_name.gsub(MasterData::Templates::AggregateTemplate::AGGREGATE_TEMPLATE_SUFFIX, '')
        end

        def icon_type
          return super unless aggregate_type_aggregate?

          icon_type = super
          base_type = icon_type.gsub("_#{MasterData::Templates::AggregateTemplate::AGGREGATE_TEMPLATE_SUFFIX.underscore_blanks}", '')

          "#{self.class.name.demodulize.underscore_blanks}-aggregate-icon #{icon_type} #{base_type}"
        end

        def translated_template_name(locale)
          return super unless aggregate_type_aggregate?

          if I18n.exists?("template_names.#{template_name}", locale:)
            I18n.t("template_names.#{template_name}", locale:)
          elsif I18n.exists?('feature.aggregate.template_name_suffix', locale:)
            "#{super} #{I18n.t('feature.aggregate.template_name_suffix', locale:)}"
          else
            super
          end
        end
      end
    end
  end
end
