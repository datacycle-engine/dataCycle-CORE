# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateStatistics
        attr_reader :outdated_templates

        def initialize(start_time: Time.zone.now)
          @start_time = start_time
          @outdated_templates = []
        end

        def update_statistics
          DataCycleCore::Thing
            .where('cache_valid_since < ?', @start_time.utc.to_s(:long_usec))
            .where(template: true)
            .order(cache_valid_since: :asc)
            .each do |template|
              @outdated_templates.push({
                name: template.template_name,
                cache_valid_since: template.cache_valid_since,
                count: DataCycleCore::Thing.where(template: false, template_name: template.template_name).count,
                count_history: DataCycleCore::Thing::History.where(template: false, template_name: template.template_name).count
              })
            end
        end
      end
    end
  end
end
