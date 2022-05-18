# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Copyright
        class << self
          def copyright_notice(computed_parameters:, data_hash:, content:, computed_definition:, key:, **_args)
            copyright_notice = []
            computed_definition.dig('compute', 'parameters')&.sort&.each do |definition|
              case content&.properties_for(definition[1])&.dig('type')
              when 'classification'
                classificiation_ids = computed_parameters.dig(definition[0]&.to_i)
                classificiation_ids&.each do |id|
                  copyright_notice.push(DataCycleCore::Classification.find(id)&.primary_classification_alias&.internal_name)
                end
              when 'linked'
                copyright_notice.push((data_hash&.key?(definition[1]) ? DataCycleCore::Thing.where(id: computed_parameters.dig(definition[0]&.to_i)) : content.try(definition[1])).map { |c| I18n.with_locale(c.first_available_locale) { c.title.presence } }.compact.join(', ').presence)
              else
                copyright_notice.push(data_hash&.key?(definition[1]) ? computed_parameters.dig(definition[0]&.to_i).presence : content.try(definition[1]).presence)
              end
            end
            copyright_notice.compact.presence&.join(' / ')&.prepend('(c) ') || content.try(key) || data_hash.dig(key)
          end
        end
      end
    end
  end
end
