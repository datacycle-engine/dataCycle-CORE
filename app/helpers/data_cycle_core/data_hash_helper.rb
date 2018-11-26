# frozen_string_literal: true

module DataCycleCore
  module DataHashHelper
    INTERNAL_PROPERTIES = DataCycleCore.internal_data_attributes + ['id']

    def object_from_definition(definition)
      return nil if definition.blank? || definition.dig('linked_table').nil? || definition.dig('template_name').nil?

      template_name = definition['template_name']
      DataCycleCore::Thing.find_by("template = true AND schema ->> 'content_type' = ? AND template_name =?", 'entity', template_name)
    end

    def ordered_validation_properties(validation:, type: nil, content_area: nil)
      return nil if validation.nil? || validation['properties'].blank?

      ordered_properties = ActiveSupport::OrderedHash.new
      validation['properties'].each do |prop|
        next if type.present? && prop[1]['type'] != type

        if content_area.present? && content_area == 'content'
          next if prop[1].dig('ui', 'show', 'content_area').present?
        elsif content_area.present?
          next if prop[1].dig('ui', 'show', 'content_area') != content_area
        end

        if prop[1]['sorting'].present? && !INTERNAL_PROPERTIES.include?(prop[0])
          ordered_properties[prop[1]['sorting'].to_i] = prop
        end
      end

      Hash[ordered_properties.sort.map { |_, v| v }]
    end

    def to_html_string(title, text = '')
      html_title = title.presence || ''
      html_title += ':' if text.present?

      html_text = text.presence || ''

      out = []
      out << content_tag(:i, html_title.html_safe)
      out << content_tag(:b, html_text.html_safe)
      safe_join(out)
    end
  end
end
