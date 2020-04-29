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

    def apply_classification_filters(query)
      return query if permitted_params&.dig(:filter, :classifications).blank?
      classification_params = permitted_params[:filter][:classifications].to_h.deep_symbolize_keys

      classification_params.each do |operator, filter|
        filter_prefix = operator == :notIn ? 'not_' : ''
        filter&.each do |k, v|
          param_to_classifications(v).each do |classifications|
            query = query.send("#{filter_prefix}classification_alias_ids_#{k.to_s.underscore}", classifications)
          end
        end
      end
      query
    end

    def attribute_filter_operations
      {
        in: [
          :max,
          :min,
          :equals,
          :like,
          :bool
        ],
        notIn: [
          :max,
          :min,
          :equals,
          :like,
          :bool
        ]
      }
    end

    private

    # TODO: add error handling
    # https://jsonapi.org/format/#errors
    def param_to_classifications(classification_string)
      classification_string.map { |classifications|
        classifications.split(',').map(&:strip).reject(&:blank?)
      }.reject(&:empty?)
    end
  end
end
