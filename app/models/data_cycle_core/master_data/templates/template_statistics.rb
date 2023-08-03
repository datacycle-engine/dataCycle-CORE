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
          DataCycleCore::ThingTemplate
            .where('updated_at < ?', @start_time.utc.to_s(:long_usec))
            .order(updated_at: :asc)
            .each do |template|
              @outdated_templates.push({
                name: template.template_name,
                cache_valid_since: template.updated_at,
                count: DataCycleCore::Thing.where(template_name: template.template_name).count,
                count_history: DataCycleCore::Thing::History.where(template_name: template.template_name).count
              })
            end
        end

        # rubocop:disable Rails/Output
        def render_statistics
          return if @outdated_templates.blank?

          puts "\nWARNING: the following templates were not updated:"
          puts "#{'template_name'.ljust(40)} | #{'cache_valid_since'.ljust(38)} | #{'#things'.ljust(12)} | #{'#things_hist'.ljust(12)}"
          puts '-' * 112
          @outdated_templates.each do |value|
            puts "#{value[:name].to_s.ljust(40)} | #{value[:cache_valid_since].to_s(:long_usec).ljust(38)} | #{value[:count].to_s.rjust(12)} | #{value[:count_history].to_s.rjust(12)}"
          end
        end
        # rubocop:enable Rails/Output
      end
    end
  end
end
