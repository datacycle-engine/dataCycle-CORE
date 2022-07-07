# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Copyright
        class << self
          def copyright_notice(computed_parameters:, content:, **_args)
            copyright_notice = []

            computed_parameters.each do |computed_key, value|
              case content&.properties_for(computed_key)&.dig('type')
              when 'classification'
                copyright_notice.concat(DataCycleCore::Classification.where(id: value).primary_classification_aliases.pluck(:internal_name))
              when 'linked'
                copyright_notice.push(DataCycleCore::Thing.where(id: value).map { |c| I18n.with_locale(c.first_available_locale) { c.title.presence } }.compact.join(', ').presence)
              when 'number'
                copyright_notice.push(value.presence&.to_i)
              else
                copyright_notice.push(value.presence)
              end
            end

            copyright_notice.compact.presence&.join(' / ')&.prepend('(c) ')
          end
        end
      end
    end
  end
end
