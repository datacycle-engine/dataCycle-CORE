module DataCycleCore
  module CreativeWorksHelper

    @@partials_path = "data_cycle_core/creative_works/partials/editor/"
    @@key_prefix = "creative_work[datahash]"

    class DataCycleFormBuilder < ActionView::Helpers::FormBuilder

      # def text_field(attribute, options={})
      #   label(attribute) + super
      # end

    end

    def set_key_prefix(prefix)
      @@key_prefix = prefix
    end

    def is_writable(permissions)
      if !permissions['read_write'].nil? && permissions['read_write'] == true
        return true
      end
      return false
    end

    def get_allowed_content_types
      allowed_content_types = {'Artikel' => 'Standard-Artikel', 'Portrait' => 'Portrait', 'Biografie' => 'Biografie', 'Social Media Posting' => 'SocialMediaPosting'}
    end

    def get_ordered_validation_properties(validation)

      ordered_properties = ActiveSupport::OrderedHash.new
      unordered_properties = []

      validation['properties'].each do |prop|

        if !prop[1]['editor'].nil?

          if !prop[1]['editor']['sorting'].nil?
            ordered_properties[prop[1]['editor']['sorting'].to_i] = prop
          else
            unordered_properties.push(prop)
          end

        end

      end

      properties = Hash[ordered_properties.sort.map{ |k,v| v}]
      return properties.merge(Hash[unordered_properties])

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

      unless prop['editor']['options'].nil?
        options.merge!(prop['editor']['options'])
      end

      if respond_to?('render_'+ data_type +'_field')
        send('render_'+ data_type +'_field', object_key, prop, value, options)
        # send('render_'+ data_type +'_field', object_key, prop, value, options)
      else
         "Unknown data_type: #{prop['type']}"
      end

    end

    def render_classificationTreeLabel_field(key, prop, value=nil, options={})
      if !prop['editor'].nil? && !prop['editor']['type'].nil?
        render partial: "#{@@partials_path}#{prop['editor']['type']}", locals: {key: key, prop: prop, value: value, options: options}
      else
        # 'editor not set'
      end
    end

    def render_embeddedLinkArray_field(key, prop, value=nil, options={})
      if !prop.blank? && !prop['type_name'].blank?
        render partial: "#{@@partials_path}#{prop['type']}", locals: {key: key, prop: prop, value: value, options: options}
      end
    end

    def render_objectBrowser_field(key, prop, value=nil, options={})
      if !prop.blank? && !prop['editor']['type'].nil?
        render partial: "#{@@partials_path}#{prop['editor']['type']}", locals: {key: key, prop: prop, value: value, options: options}
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

      else

        if !prop['name'].nil? && !prop['description'].nil? && !prop['editor']['type'].nil?
          key = get_object_key(key)
          render_objectBrowser_field(key, prop, value, options)
        end

      end

    end

    def render_string_field(key, prop, value=nil, options={})

      if !prop['editor'].nil? && !prop['editor']['type'].nil?
        case prop['editor']['type']
          when 'input'
            render_input_text_field(key, value, prop['label'], options)
          when 'date'
            render_date_input_text_field(key, value, prop['label'], options)
          when 'quillEditor'
            render_fe_editor(key, value, prop['label'], options)
        end
      else
        render_input_text_field(key, value, prop['label'], options)
      end

    end

    def render_fe_editor(key, value=nil, label=nil, options={})
      render partial: "#{@@partials_path}feEditor", locals: {key: key, value: value, label: label, options: options}
    end

    def render_input_text_field(key, value=nil, label=nil, options={})
      render partial: "#{@@partials_path}input", locals: {key: key, value: value, label: label, options: options}
    end

    def render_date_input_text_field(key, value=nil, label=nil, options={})
      render partial: "#{@@partials_path}dateInput", locals: {key: key, value: value, label: label, options: options}
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
