module DataCycleCore
  module DataHashHelper
    INTERNAL_PROPERTIES = DataCycleCore.internal_data_attributes + ['id']
    # @@partials_path = 'data_cycle_core/creative_works/partials/edit/datatype/'
    # @@key_prefix = 'creative_work[datahash]'

    class DataCycleFormBuilder < ActionView::Helpers::FormBuilder
      # def text_field(attribute, options={})
      #   label(attribute) + super
      # end
    end

    # def set_key_prefix(prefix)
    #   @@key_prefix = prefix
    # end

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
