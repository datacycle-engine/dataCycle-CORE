# frozen_string_literal: true

module DataCycleCore
  module ApiService
    def list_api_request(contents = nil)
      contents ||= @contents
      json_context = api_plain_context(@language)
      json_contents = contents.map do |item|
        Rails.cache.fetch("api_v4_#{api_cache_key(item, @language, @include_parameters, @fields_parameters, @api_subversion)}", expires_in: 1.year + Random.rand(7.days)) do
          item.to_api_list
        end
      end
      json_links = api_plain_links(contents)
      list_hash = {
        '@context' => json_context,
        '@graph' => json_contents,
        'links' => json_links
      }
      list_hash['meta'] = api_plain_meta(contents.total_count, contents.total_pages) unless @mode_parameters == 'strict'
      list_hash
    end
  end
end