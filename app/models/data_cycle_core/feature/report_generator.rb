# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ReportGenerator < Base
      class << self
        def ability_class
          DataCycleCore::Feature::Abilities::ReportGenerator
        end

        def global_reports
          config.dig('global').select { |_k, v| v.dig('enabled') == true }
        end

        def content_reports
          config.dig('content').select { |_k, v| v.dig('enabled') == true }
        end

        def by_identifier(identifier)
          global_reports.dig(identifier, 'class') || content_reports.dig(identifier, 'class')
        end

        def config
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym).dig(:config)
        end
      end
    end
  end
end
