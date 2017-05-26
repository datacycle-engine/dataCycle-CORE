module DataCycleCore
  module CreativeWorksHelper

    @@partials_path = "data_cycle_core/creative_works/partials/editor/"
    @@key_prefix = "creative_work[datahash]"

    class DataCycleFormBuilder < ActionView::Helpers::FormBuilder

      # def text_field(attribute, options={})
      #   label(attribute) + super
      # end

    end

    def data_cycle_field(key, prop, value = nil, options = {}, parents=[])
      unless prop['editor'] || prop['type'] == 'object'
        # return "No properties for editor set"
        return
      end

      object_key = get_object_key(key, parents)
      if prop['type'] == 'object'
        object_key = key
      end
      data_type = prop['type']

      if !prop['editor']['options'].nil?
        options.merge!(prop['editor']['options'])
      end

      if respond_to?('render_'+ data_type +'_field')
        label_tag(key, prop['label']) + send('render_'+ data_type +'_field', object_key, prop, value, options)
        # send('render_'+ data_type +'_field', object_key, prop, value, options)
      else
         "Unknown data_type: #{prop['type']}"
      end

    end

    def render_object_field(key, prop, value=nil, options={})
      #raise prop.inspect
      if !prop['properties'].nil?
        output = []

        prop['properties'].each do |object_key, object_property|
          output.push(data_cycle_field(object_key, object_property, value, options, [key]))
        end

        output.join('').html_safe
      end

    end

    def render_string_field(key, prop, value=nil, options={})

      if !prop['editor'].nil? && !prop['editor']['type'].nil?
        case prop['editor']['type']
          when 'input'
            render_input_text_field(key, value, options)
          when 'rte'
            render_fe_editor(key, value, options)
        end
      else
        render_input_text_field(key, value, options)
      end

    end

    def render_fe_editor(key, value=nil, options={})
      render partial: "#{@@partials_path}feEditor", locals: {key: key, value: value, options: options}
    end

    def render_input_text_field(key, value=nil, options={})
      render partial: "#{@@partials_path}input", locals: {key: key, value: value, options: options}
    end

    private

      def get_object_key(key, parents = [])
        parent_keys = ''
        if !parents.empty?
          parent_keys = parents.map{ |parent| "[#{parent}]" }.join('')
        end
        object_key = "#{@@key_prefix}#{parent_keys}[#{key}]"
      end

  end
end
