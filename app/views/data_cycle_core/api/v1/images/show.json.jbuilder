@image.translated_locales.each do |language|
  I18n.with_locale(language) do
    json.partial! 'image', locals: {language: language, image: @image }
  end
end
