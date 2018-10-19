# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Container < Base
      class << self
        def available_containers
          @available_containers ||= DataCycleCore::CreativeWork.where(template: true).where("schema ->> 'content_type' = ?", 'container').order(:template_name)
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

        def allowed_classification_aliases(content)
          configuration(content).dig('classification_alias')
        end

        def index_query_methods
          ca_names = available_containers.map { |a| allowed_classification_aliases(a) }.flatten.uniq
          cad_names = DataCycleCore::ClassificationAlias.with_name(ca_names).with_descendants.map(&:name)

          return nil unless enabled?

          [
            {
              method_name: 'without_name',
              value: cad_names
            }
          ]
        end

        def query_methods(content)
          [
            {
              method_name: 'with_name',
              value: allowed_classification_aliases(content)
            },
            {
              method_name: 'with_descendants'
            }
          ]
        end
      end
    end
  end
end
