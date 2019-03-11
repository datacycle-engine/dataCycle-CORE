# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ImageOptimizer < Base
      class << self
        def optimize_versions
          configuration&.dig('versions') || []
        end

        def config
          configuration&.dig('config') || {}
        end

        def optimize?(version)
          version ||= :original
          enabled? && (optimize_versions.blank? || optimize_versions.include?(version.to_s))
        end

        def version_regex
          return if optimize_versions.blank?

          regex = []
          regex.push('????????-????-????-????????????') if optimize_versions.include?('original')
          regex.concat(optimize_versions.reject { |v| v == 'original' }.map { |v| "#{v}_" }).join(',')
        end
      end
    end
  end
end
