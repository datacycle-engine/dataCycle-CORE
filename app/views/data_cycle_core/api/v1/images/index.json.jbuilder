json.images @images do |item|
  item.translated_locales.each do |language|
    I18n.with_locale(language) do
      json.partial! 'image', locals: {language: language, image: item }
    end
  end
end

std_params = "per=#{params[:per] || @per}&token=#{params[:token]}"
json.set! "links", {
  first: "#{api_v1_images_url}.json?page=#{1.to_s}&#{std_params}",
  prev: @images.first_page? ? nil : "#{api_v1_images_url}.json?page=#{@images.prev_page.to_s}&#{std_params}",
  next: @images.last_page?  ? nil : "#{api_v1_images_url}.json?page=#{@images.next_page.to_s}&#{std_params}",
  last: "#{api_v1_images_url}.json?page=#{@images.total_pages.to_s}&#{std_params}"
}.compact
