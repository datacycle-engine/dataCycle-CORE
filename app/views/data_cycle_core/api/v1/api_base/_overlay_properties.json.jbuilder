# frozen_string_literal: true

DataCycleCore::Feature::OverlayAttributeService.call(content).each do |property|
  data = content.try(:send, property).includes(:translations, :classifications)

  next if data.blank?
  data.each do |item|
    json.cache!(api_cache_key(item, I18n.locale, [], []), expires_in: 24.hours + Random.rand(12.hours)) do
      json.content_partial! 'overlay', content: item
    end
  end
end
