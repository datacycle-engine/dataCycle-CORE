# frozen_string_literal: true

key_new = definition.dig('api', 'name') || key.camelize(:lower)

if value.present? && value.first.template_name != 'EventSchedule' # for e.g. Schedule in Tours (= Season)
  json.partial! 'data_cycle_core/api/v2/api_base/attributes/embedded', key: key, definition: content.properties_for(key), value: value, options: options, content: content
elsif content.try(:event_schedule).present?
  data = content.event_schedule.to_a.map(&:to_schedule_schema_org_api_v2)
  json.set! key_new do
    if content.translations.size > 1 && @include_parameters.include?('translations')
      content.translations.each do |trans|
        json.set! trans.locale do
          json.array! data do |schedule_hash|
            schedule_hash.each do |key, value|
              json.set! key, value
            end
          end
        end
      end
    else
      json.array! data do |schedule_hash|
        schedule_hash.each do |key, value|
          json.set! key, value
        end
      end
    end
  end
end
