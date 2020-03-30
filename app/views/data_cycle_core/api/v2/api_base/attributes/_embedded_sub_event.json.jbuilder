# frozen_string_literal: true

key_new = definition.dig('api', 'name') || key.camelize(:lower)

if content.try(:event_schedule).present? && content.event_schedule&.size == 1 && content.event_schedule&.first&.schedule_object&.terminating?
  data = content.event_schedule.first.to_sub_event_api_v2
  data = data.map { |i| i.merge({ 'sameAs' => content.url }) } if content.url.present?
  json.set! key_new do
    json.merge! data
  end
end
