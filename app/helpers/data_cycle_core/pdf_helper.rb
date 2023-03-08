# frozen_string_literal: true

module DataCycleCore
  module PdfHelper
    PDF_PROPERTY_TYPES = [
      'string',
      'embedded',
      'linked'
    ].freeze

    def render_pdf_content(content:, path_prefix: '', options: { header_depth: 1 })
      partials = [
        content.try(:template_name)&.underscore_blanks,
        'default'
      ].compact_blank.map { |p| File.join('data_cycle_core/pdf/contents', path_prefix, p) }

      render_first_existing_partial(partials, options.merge({ content: content }))
    end

    def render_pdf_properties(content:, whitelist: [], blacklist: [], options: {})
      return if content.schema.nil? || content.schema['properties'].blank?

      capture do
        content.schema['properties'].sort_by { |_, prop| prop['sorting'] }.each do |key, prop|
          next if PDF_PROPERTY_TYPES.exclude?(prop['type'])
          next if DataCycleCore::DataHashHelper::INTERNAL_PROPERTIES.include?(key)
          next if Array.wrap(whitelist).presence&.exclude?(key)
          next if Array.wrap(blacklist).presence&.include?(key)
          next if prop.dig('pdf', 'disabled').to_s == 'true'

          concat render_pdf_property(content: content, key: key, prop: prop, options: options)
        end
      end
    end

    def render_pdf_property(content:, key:, prop:, options: {})
      partials = [
        prop&.dig('pdf', 'partial').presence,
        "#{prop['type']}_#{key}",
        prop.dig('pdf', 'type')&.underscore_blanks&.prepend(prop['type'], '_').presence,
        prop.dig('validations', 'format')&.underscore_blanks&.prepend(prop['type'], '_').presence,
        prop['type'].to_s
      ].compact_blank.map { |p| "data_cycle_core/pdf/contents/attributes/#{p}" }

      value = content.try(key)

      return if value.blank?

      render_first_existing_partial(partials, options.merge({ content: content, key: key, definition: prop, value: value }))
    end
  end
end
