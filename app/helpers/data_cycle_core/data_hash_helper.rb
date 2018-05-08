module DataCycleCore
  module DataHashHelper
    INTERNAL_PROPERTIES = DataCycleCore.internal_data_attributes + ['id']

    def object_from_definition(definition)
      return nil if definition.blank? || definition.dig('linked_table').nil? || definition.dig('template_name').nil?
      object_type = "DataCycleCore::"+ definition['linked_table'].classify
      template_name = definition['template_name']
      object_type.constantize.find_by("template = true AND schema ->> 'content_type' = ? AND template_name =?", 'entity', template_name)
    end

    def ordered_validation_properties(validation)
      return nil if validation.nil? || validation['properties'].blank?

      ordered_properties = ActiveSupport::OrderedHash.new

      validation['properties'].each do |prop|
        if prop[1]['sorting'].present? && !INTERNAL_PROPERTIES.include?(prop[0])
          ordered_properties[prop[1]['sorting'].to_i] = prop
        end
      end

      Hash[ordered_properties.sort.map { |_, v| v }]
    end

    def to_html_string(title, text = '')
      html_title = ''
      unless title.blank?
        html_title += '<i>'
        html_title += title

        html_title += ':' unless text.blank?

        html_title += '</i>'
      end

      html_text = ''
      unless text.blank?
        html_text += '<b> '
        html_text += text
        html_text += '</b>'
      end

      html_tag = html_title + html_text

      html_tag.html_safe
    end

    # TODO: move to mixins
    def normalize_value(value = nil)
      value = value.reject(&:blank?) if value.is_a?(Array)
      value
    end
  end
end
