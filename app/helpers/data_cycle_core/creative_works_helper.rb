module DataCycleCore
  module CreativeWorksHelper

    @@partials_path = "data_cycle_core/creative_works/partials/edit/datatype/"
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
      allowed_content_types = {'Angebot' => 'Angebot', 'App' => 'App', 'Artikel' => 'Standard-Artikel', 'Biografie' => 'Biografie', 'Interview' => 'Interview', 'Linktipps' => 'Linktipps', 'Portrait' => 'Portrait', 'Quiz' => 'Quiz', 'Rezept' => 'Rezept', 'Social Media Posting' => 'SocialMediaPosting', 'Voting' => 'Voting', 'Zeitleiste' => 'Zeitleiste'}
      allowed_content_types = {'Angebot' => 'Angebot', 'App' => 'App', 'Artikel' => 'Standard-Artikel', 'Biografie' => 'Biografie', 'Interview' => 'Interview', 'Linktipps' => 'Linktipps', 'Portrait' => 'Portrait', 'Rezept' => 'Rezept', 'Social Media Posting' => 'SocialMediaPosting', 'Voting' => 'Voting', 'Zeitleiste' => 'Zeitleiste'}
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

    def data_cycle_hidden_field(key, value = nil, parents=[])
      object_key = get_object_key(key, parents)
      hidden_field_tag(object_key, value)
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
          send('render_'+ data_type +'_field', object_key, prop, normalize_value(value), options, parents)
      else
         "Unknown data_type: #{prop['type']}"
      end

    end

    def render_classificationTreeLabel_field(key, prop, value=nil, options={}, parents=[])
      if !prop['editor'].nil? && !prop['editor']['type'].nil?
        render partial: "#{@@partials_path}#{prop['editor']['type']}", locals: {key: key, prop: prop, value: value, options: options, parents: parents}
      else
        # 'editor not set'
      end
    end

    def render_embeddedLinkArray_field(key, prop, value=nil, options={}, parents=[])
      if !prop.blank? && !prop['type_name'].blank?
        render partial: "#{@@partials_path}#{prop['type']}", locals: {key: key, prop: prop, value: value, options: options, parents: parents}
      end
    end

    def render_objectBrowser_field(key, prop, value=nil, options={}, parents=[])
      if !prop.blank? && !prop['editor']['type'].nil?
        render partial: "#{@@partials_path}#{prop['editor']['type']}", locals: {key: key, prop: prop, value: value, options: options, parents: parents}
      end
    end

    def render_embeddedObject_field(key, prop, value=nil, options={}, parents=[])
      if !prop.blank? && !prop['editor']['type'].nil?
        internal_template = get_internal_template(prop['storage_location'], prop['name'], prop['description'])
        internal_objects = get_internal_data(prop['storage_location'], value)
        render partial: "#{@@partials_path}#{prop['editor']['type']}", locals: {key: key, prop: prop, value: value, options: options, internal_objects: internal_objects, internal_template: internal_template, parents: parents}
      end
    end

    def render_object_field(key, prop, value=nil, options={}, parents=[])
      #raise prop.inspect
      if !prop['properties'].nil?
        output = []

        prop['properties'].each do |object_key, object_property|
          output.push(data_cycle_field(object_key, object_property, value, options, [key]))
        end

        output.join('').html_safe

      else

        if !prop['name'].nil? && !prop['description'].nil? && !prop['editor']['type'].nil?

          case prop['editor']['type']
            when 'embeddedObject'
              render_embeddedObject_field(key, prop, value, options, parents)
            when 'objectBrowser'
              key = get_object_key(key, parents)
              render_objectBrowser_field(key, prop, value, options)
          end

        end

      end

    end

    def render_string_field(key, prop, value=nil, options={}, parents=[])

      if !prop['editor'].nil? && !prop['editor']['type'].nil?
        case prop['editor']['type']
          when 'input'
            render_input_text_field(key, prop, value, prop['label'], options, parents: parents)
          when 'date'
            render_date_input_text_field(key, prop, value, prop['label'], options, parents: parents)
          when 'datetime'
            render_datetime_input_text_field(key, prop, value, prop['label'], options, parents: parents)
          when 'quillEditor'
            render_fe_editor(key, prop, value, prop['label'], options, parents: parents)
        end
      else
        render_input_text_field(key, prop, value, prop['label'], options, parents: parents)
      end

    end

    def render_number_field(key, prop, value=nil, options={}, parents=[])

      if !prop['editor'].nil? && !prop['editor']['type'].nil?
        case prop['editor']['type']
          when 'duration'
            render_input_duration_field(key, prop, value, prop['label'], options, parents: parents)
        end
      else
        render_input_text_field(key, prop, value, prop['label'], options, parents: parents)
      end

    end

    def render_fe_editor(key, prop, value=nil, label=nil, options={}, parents=[])
      render partial: "#{@@partials_path}feEditor", locals: {key: key, value: value, label: label, prop: prop, options: options, parents: parents}
    end

    def render_input_text_field(key, prop, value=nil, label=nil, options={}, parents=[])
      render partial: "#{@@partials_path}input", locals: {key: key, value: value, label: label, prop: prop, options: options, parents: parents}
    end

    def render_date_input_text_field(key, prop, value=nil, label=nil, options={}, parents=[])
      render partial: "#{@@partials_path}dateInput", locals: {key: key, value: value, label: label, prop: prop, options: options, parents: parents}
    end

    def render_datetime_input_text_field(key, prop, value=nil, label=nil, options={}, parents=[])
      render partial: "#{@@partials_path}dateTimeInput", locals: {key: key, value: value, label: label, prop: prop, options: options, parents: parents}
    end

    def render_input_duration_field(key, prop, value=nil, label=nil, options={}, parents=[])
      render partial: "#{@@partials_path}duration", locals: {key: key, value: value, label: label, prop: prop, options: options, parents: parents}
    end

    private

      def get_object_key(key, parents = [])
        parent_keys = ''
        if !parents.empty?
          parent_keys = parents.map{ |parent| "[#{parent}]" }.join('')
        end
        object_key = "#{@@key_prefix}#{parent_keys}[#{key}]"
      end

      def get_internal_data(storage_location, value)

        internal_objects = []
        if !value.empty? && value.count > 0
          value.each do |object|
            internal_object = ("DataCycleCore::"+storage_location.classify).constantize.
                find_by(id: object['id'])
            internal_objects.push(internal_object) unless internal_object.blank?
          end
        else
          return nil
        end

        return internal_objects

      end

      def get_internal_template(storage_location, name, description)

        internal_template = ("DataCycleCore::"+storage_location.classify).constantize.
            find_by(template: true, headline: name, description: description)

        if internal_template.blank?
          return nil
        end

        return internal_template

      end

      def normalize_value(value=nil)
        if value.kind_of?(Array)
          value = value.reject { |v| v.empty? }
        end
        return value
      end

  end
end
