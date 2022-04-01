# frozen_string_literal: true

DataCycleCore::Feature::OverlayAttributeService.call(content).each do |property|
  data = content.try(:send, property).includes(:translations, :classifications)

  next if data.blank?
  data.each do |item|
    json.cache!(api_cache_key(item, @language, @include_parameters, @mode_parameters, @api_subversion), expires_in: 1.year + Random.rand(7.days)) do
      json.content_partial! 'details', content: item, options: options.merge({ header_type: :overlay })
    end
  end
end
