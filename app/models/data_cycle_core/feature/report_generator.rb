# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ReportGenerator < Base
      class << self
        def by_identifier(identifier, content = nil)
          return content_reports(content).dig(identifier, 'class') if content.present?
          global_reports.dig(identifier, 'class')
        end

        def global_reports
          config['global'].select { |_k, v| v['enabled'] == true }
        end

        def content_reports(content)
          config(content)['content'].select { |_k, v| v['enabled'] == true }
        end

        def config(content = nil)
          configuration(content)[:config]
        end
      end
    end
  end
end
