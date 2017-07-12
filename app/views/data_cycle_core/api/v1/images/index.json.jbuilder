json.images @images do |item|
  json.partial! 'image_translation_format', locals: {image: item }
end

std_params = "per=#{params[:per] || @per}&token=#{params[:token]}"
json.set! "total", @total
# json.set! "links", {
#   first: "#{api_v1_images_url}.json?page=#{1.to_s}&#{std_params}",
#   prev: @images.first_page? ? nil : "#{api_v1_images_url}.json?page=#{@images.prev_page.to_s}&#{std_params}",
#   next: @images.last_page?  ? nil : "#{api_v1_images_url}.json?page=#{@images.next_page.to_s}&#{std_params}",
#   last: "#{api_v1_images_url}.json?page=#{@images.total_pages.to_s}&#{std_params}"
# }.compact
