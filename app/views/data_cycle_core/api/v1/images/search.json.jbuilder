I18n.with_locale(@language) do
  json.images @images do |item|
    data_hash = { "@context" => "http://www.schema.org/ImageObject", "@id" => item.id }
    data_hash.merge!(item.get_data_hash.compact)
    json.set! @language, data_hash
  end
end


json.set! "links", {
  first: "#{api_v1_images_search_url}.json?page=#{1.to_s}&per=#{params[:per] || @per}&search=#{params[:search]}&language=#{params[:language]}",
  prev: @images.first_page? ? nil : "#{api_v1_images_search_url}.json?page=#{@images.prev_page.to_s}&per=#{params[:per] || @per}&search=#{params[:search]}&language=#{params[:language]}",
  next: @images.last_page?  ? nil : "#{api_v1_images_search_url}.json?page=#{@images.next_page.to_s}&per=#{params[:per] || @per}&search=#{params[:search]}&language=#{params[:language]}",
  last: "#{api_v1_images_search_url}.json?page=#{@images.total_pages.to_s}&per=#{params[:per] || @per}&search=#{params[:search]}&language=#{params[:language]}"
}.compact
