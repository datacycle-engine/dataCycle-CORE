# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  data = content.send(key).includes(:translations, :classifications)
  next if data.empty?

  key_new = definition.dig('api', 'name') || key.camelize(:lower)
  json.set! key_new do
    json.array!(data) do |item|
      if @include_parameters.include?('linked')
        @duplicate_linked_in_path ||= []

        if @duplicate_linked_in_path.include?(item.id)
          json.cache!(api_cache_key(item, @language, @include_parameters, (@mode_parameters || []) + ['header_only'], @api_subversion), expires_in: 24.hours + Random.rand(12.hours)) do
            json.content_partial! 'header', content: item, options: options
          end
        else
          @duplicate_linked_in_path << item.id
          json.cache!(api_cache_key(item, @language, @include_parameters, @mode_parameters, @api_subversion), expires_in: 1.year + Random.rand(7.days)) do
            json.content_partial! 'details', content: item
          end
          @duplicate_linked_in_path.delete(item.id)
        end
      else
        json.content_partial! 'header', content: item, options: options.merge({ header_type: :linked })
      end
    end
  end
end
