# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Container < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::Container
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::Container
        end

        def available_containers
          @available_containers ||= DataCycleCore::Thing.where(template: true, content_type: 'container').order(:template_name)
        end

        def allowed_container_templates(content)
          template_names = []

          available_containers.each do |container_template|
            template_names << container_template.template_name if allowed_templates(container_template)&.include?(content.template_name)
          end

          template_names
        end

        def allowed_templates(content)
          configuration(content).dig('allowed_templates')
        end

        def index_query_methods
          return [] unless enabled?

          ca_names = available_containers.map { |a| allowed_templates(a) }.flatten.uniq
          ca_names = ca_names.without(DataCycleCore::Feature::IdeaCollection.template_name) if DataCycleCore::Feature::IdeaCollection.enabled?

          [
            {
              method_name: 'without_template_names',
              value: ca_names
            }
          ]
        end

        def query_methods(content)
          queries = [
            {
              method_name: 'with_template_names',
              value: allowed_templates(content)
            }
          ]

          return queries unless content.try(:life_cycle_stage_index, DataCycleCore::Feature::IdeaCollection.life_cycle_stage(content))&.<(content.life_cycle_stage_index)

          queries.push({
            method_name: 'without_template_names',
            value: DataCycleCore::Feature::IdeaCollection.template_name(content)
          })
        end
      end
    end
  end
end
