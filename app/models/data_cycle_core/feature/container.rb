# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Container < Base
      class << self
        def available_containers
          @available_containers ||= DataCycleCore::Thing.where(template: true).where("schema ->> 'content_type' = ?", 'container').order(:template_name)
        end

        def allowed_classification_aliases(content)
          configuration(content).dig('classification_alias')
        end

        def index_query_methods
          ca_names = available_containers.map { |a| allowed_classification_aliases(a) }.flatten.uniq
          ca_names = ca_names.without(DataCycleCore::Feature::IdeaCollection.template_data_type) if DataCycleCore::Feature::IdeaCollection.enabled?

          cad_names = DataCycleCore::ClassificationAlias.with_name(ca_names).with_descendants.map(&:name)

          return [] unless enabled?

          [
            {
              method_name: 'without_name',
              value: cad_names
            }
          ]
        end

        def query_methods(content)
          queries = [
            {
              method_name: 'with_name',
              value: allowed_classification_aliases(content)
            },
            {
              method_name: 'with_descendants'
            }
          ]

          return queries unless content.life_cycle_stage_index > content.life_cycle_stage_index(DataCycleCore::Feature::IdeaCollection.life_cycle_stage(content))

          queries.push({
            method_name: 'without_name',
            value: DataCycleCore::Feature::IdeaCollection.template_data_type(content)
          })
        end
      end
    end
  end
end
