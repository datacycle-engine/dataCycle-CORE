module DataCycleCore
  module CreativeWorksHelper

    class DataCycleFormBuilder < ActionView::Helpers::FormBuilder

      def text_field(attribute, options={})
        label(attribute) + super
      end

    end

    def data_cycle_field(key, prop, value = nil, options = {})
      object_key = get_object_key(key)
      data_type = prop['type']

      if respond_to?('render_'+ data_type +'_field')
        send('render_'+ data_type +'_field', object_key, prop, value, options)
      else
        # "Unknown data_type: #{prop['type']}"
      end
    end

    def render_string_field(key, prop, value=nil, options={})
      if !prop['storage_type'].nil?
        case prop['storage_type']
          when 'string'
            text_field_tag(key, value, options)
          when 'text'
            render_fe_editor(key, value, options)
        end
      else
        text_field_tag(key, value, options)
      end
    end

    def render_fe_editor(key, value=nil, options={})
      render partial: "feEditor", locals: {key: key, value: value, options: options}
    end

    private
      def get_object_key(key)
        key_prefix = "creative_work[datahash]"
        object_key = "#{key_prefix}[#{key}]"
      end
  end
end
