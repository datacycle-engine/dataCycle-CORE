# frozen_string_literal: true

DataCycleCore::Feature::OverlayAttributeService.call(content).each do |property|
  data = content.try(:send, property).includes(:translations, :classifications)

  next if data.blank?
  data.each do |item|
    json.cache!("#{item.class}_#{item.id}_#{item.first_available_locale(@language.to_sym)}_#{item.updated_at}_#{@include_parameters.join('_')}", expires_in: 1.year + Random.rand(7.days)) do
      json.content_partial! 'details', content: item, options: options.merge({ header_type: :overlay })
    end
  end
end
