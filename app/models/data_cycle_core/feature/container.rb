# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Container < Base
      class << self
        def available_containers
          DataCycleCore::CreativeWork.where(template: true).where("schema ->> 'content_type' = ?", 'container').order(:template_name)
        end

        def apply_excluded_contents(content, entities)
          return entities if excluded_contents(content).blank?
          entities.where.not(template_name: excluded_contents(content))
        end

        def apply_allowed_contents(content, entities)
          return entities if allowed_contents(content).blank?
          entities.where(template_name: allowed_contents(content))
        end

        def allowed_contents(content)
          content&.schema&.dig('features', name.demodulize.underscore, 'allowed') || DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :allowed) || []
        end

        def excluded_contents(content)
          content&.schema&.dig('features', name.demodulize.underscore, 'excluded') || DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :excluded) || []
        end
      end
    end
  end
end
