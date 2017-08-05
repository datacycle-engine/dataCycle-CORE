
if translations.size == 1 
  json.set! 'inLanguage', translations.first.locale

  if translations.first.streetAddress || translations.first.postalCode || translations.first.addressLocality || translations.first.addressCountry
    json.set! 'address' do
      json.partial! 'address', addressData: translations.first
    end
  end

  Array(translations.first.attributes).reject { |k, v| ignore_attribute.call(k, v) }.each do |key, value|
    json.set! key, value
  end

  Array(translations.first.content).reject { |k, v| ignore_attribute.call(k, v) }.each do |key, value|
    json.set! key, value
  end

  Array(translations.first.properties).reject { |k, v| ignore_attribute.call(k, v) }.each do |key, value|
    json.set! key, value
  end  
else
  json.set! 'translations' do
    translations.each.each do |translation|
      json.set! translation.locale do
        if translation.streetAddress || translation.postalCode || translation.addressLocality || translation.addressCountry
          json.set! 'address' do
            json.partial! 'address', addressData: translation
          end
        end

        Array(translation.attributes).reject { |k, v| ignore_attribute.call(k, v) }.each do |key, value|
          json.set! key, value
        end

        Array(translation.content).reject { |k, v| ignore_attribute.call(k, v) }.each do |key, value|
          json.set! key, value
        end

        Array(translation.properties).reject { |k, v| ignore_attribute.call(k, v) }.each do |key, value|
          json.set! key, value
        end
      end
    end
  end
end
