module DataCycleCore
  module DataHashHelper

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
      allowed_content_types = {'Angebot' => 'Angebot', 'App' => 'App', 'Artikel' => 'Standard-Artikel', 'Biografie' => 'Biografie', 'Interview' => 'Interview', 'Linktipps' => 'Linktipps', 'Portrait' => 'Portrait', 'Quiz' => 'Quiz', 'Rezept' => 'Rezept', 'Social Media Posting' => 'SocialMediaPosting', 'Veranstaltung' => 'Veranstaltung', 'Voting' => 'Voting', 'Zeitleiste' => 'Zeitleiste'}
    end

    def get_ordered_validation_properties(validation)

      ordered_properties = ActiveSupport::OrderedHash.new
      unordered_properties = []

      if !validation.nil? && !validation['properties'].blank?

        validation['properties'].each do |prop|

          if !prop[1]['editor'].nil?

            if !prop[1]['editor']['sorting'].nil?
              ordered_properties[prop[1]['editor']['sorting'].to_i] = prop
            else
              unordered_properties.push(prop)
            end

          end

        end

      end

      properties = Hash[ordered_properties.sort.map{ |k,v| v}]
      return properties.merge(Hash[unordered_properties]).nil? ? [] : properties.merge(Hash[unordered_properties])

    end

    def data_cycle_hidden_field(key, value = nil, parent_object_keys=[])
      object_key = get_object_key(key, parent_object_keys)
      hidden_field_tag(object_key, value)
    end

    def data_cycle_field(key, prop, value = nil, options = {}, parent_object_keys=[])
      unless prop['editor'] || prop['type'] == 'object'
        # return "No properties for editor set"
        return
      end

      object_key = get_object_key(key, parent_object_keys)

      if prop['type'] == 'object'
        object_key = key
      end

      data_type = prop['type']

      unless prop['editor']['options'].nil?
        options.merge!(prop['editor']['options'])
      end

      if respond_to?('render_'+ data_type +'_field')
        if(prop['releasable'])
          render partial: "#{@@partials_path}releasable", locals: {key: object_key, prop: prop, value: normalize_value(value), options: options, parent_object_keys: parent_object_keys}
        else
          send('render_'+ data_type +'_field', object_key, prop, normalize_value(value), options, parent_object_keys)
        end
      else
         "Unknown data_type: #{prop['type']}"
      end

    end

    def render_classificationTreeLabel_field(key, prop, value=nil, options={}, parent_object_keys=[])
      if !prop['editor'].nil? && !prop['editor']['type'].nil?
        render partial: "#{@@partials_path}#{prop['editor']['type']}", locals: {key: key, prop: prop, value: value, options: options, parent_object_keys: parent_object_keys}
      else
        # 'editor not set'
      end
    end

    def render_embeddedLinkArray_field(key, prop, value=nil, options={}, parent_object_keys=[])
      if !prop.blank? && !prop['type_name'].blank?
        render partial: "#{@@partials_path}#{prop['type']}", locals: {key: key, prop: prop, value: value, options: options, parent_object_keys: parent_object_keys}
      end
    end

    def render_geographic_field(key, prop, value=nil, options={}, parent_object_keys=[])
      if !prop.blank? && !prop['type'].blank?
        render partial: "#{@@partials_path}#{prop['type']}", locals: {key: key, prop: prop, value: value, options: options, parent_object_keys: parent_object_keys}
      end
    end

    def render_objectBrowser_field(key, prop, value=nil, options={}, parent_object_keys=[])
      if !prop.blank? && !prop['editor']['type'].nil?
        render partial: "#{@@partials_path}#{prop['editor']['type']}", locals: {key: key, prop: prop, value: value, options: options, parent_object_keys: parent_object_keys}
      end
    end

    def render_embeddedObject_field(key, prop, value=nil, options={}, parent_object_keys=[])
      if !prop.blank? && !prop['editor']['type'].nil?
        internal_template = DataCycleCore::DataHashService.get_internal_template(prop['storage_location'], prop['name'], prop['description'])
        internal_objects = DataCycleCore::DataHashService.get_internal_data(prop['storage_location'], value)
        render partial: "#{@@partials_path}#{prop['editor']['type']}", locals: {key: key, prop: prop, value: value, options: options, internal_objects: internal_objects, internal_template: internal_template, parent_object_keys: parent_object_keys}
      end
    end

    def render_object_field(key, prop, value=nil, options={}, parent_object_keys=[])
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
              render_embeddedObject_field(key, prop, value, options, parent_object_keys)
            when 'objectBrowser'
              key = get_object_key(key, parent_object_keys)
              render_objectBrowser_field(key, prop, value, options)
          end

        end

      end

    end

    def render_string_field(key, prop, value=nil, options={}, parent_object_keys=[])

      if !prop['editor'].nil? && !prop['editor']['type'].nil?
        case prop['editor']['type']
          when 'input'
            render_input_text_field(key, prop, value, prop['label'], options, parent_object_keys)
          when 'date'
            render_date_input_text_field(key, prop, value, prop['label'], options, parent_object_keys)
          when 'datetime'
            render_datetime_input_text_field(key, prop, value, prop['label'], options, parent_object_keys)
          when 'quillEditor'
            render_fe_editor(key, prop, value, prop['label'], options, parent_object_keys)
        end
      else
        render_input_text_field(key, prop, value, prop['label'], options, parent_object_keys)
      end

    end

    def render_number_field(key, prop, value=nil, options={}, parent_object_keys=[])

      if !prop['editor'].nil? && !prop['editor']['type'].nil?
        case prop['editor']['type']
          when 'duration'
            render_input_duration_field(key, prop, value, prop['label'], options, parent_object_keys)
        end
      else
        render_input_text_field(key, prop, value, prop['label'], options, parent_object_keys)
      end

    end

    def render_fe_editor(key, prop, value=nil, label=nil, options={}, parent_object_keys=[])
      render partial: "#{@@partials_path}feEditor", locals: {key: key, value: value, label: label, prop: prop, options: options, parent_object_keys: parent_object_keys}
    end

    def render_input_text_field(key, prop, value=nil, label=nil, options={}, parent_object_keys=[])
      render partial: "#{@@partials_path}input", locals: {key: key, value: value, label: label, prop: prop, options: options, parent_object_keys: parent_object_keys}
    end

    def render_date_input_text_field(key, prop, value=nil, label=nil, options={}, parent_object_keys=[])
      render partial: "#{@@partials_path}dateInput", locals: {key: key, value: value, label: label, prop: prop, options: options, parent_object_keys: parent_object_keys}
    end

    def render_datetime_input_text_field(key, prop, value=nil, label=nil, options={}, parent_object_keys=[])
      render partial: "#{@@partials_path}dateTimeInput", locals: {key: key, value: value, label: label, prop: prop, options: options, parent_object_keys: parent_object_keys}
    end

    def render_input_duration_field(key, prop, value=nil, label=nil, options={}, parent_object_keys=[])
      render partial: "#{@@partials_path}duration", locals: {key: key, value: value, label: label, prop: prop, options: options, parent_object_keys: parent_object_keys}
    end

    def to_html_string title, text = ''
      html_title = ''
      unless title.blank?
        html_title += '<i>'
        html_title += title

        unless text.blank?
          html_title += ':'
        end

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

    # Show action
    def get_object_data_for_show_action(storage_location, value)
      return DataCycleCore::DataHashService.get_internal_data(storage_location, value)
    end

    # todo: move to mixins
    def normalize_value(value=nil)
      if value.kind_of?(Array)
        value = value.reject { |v| v.empty? }
      end
      return value
    end

    def is_in_watchlist?(watchlist, item)
      !watchlist.watch_list_data_hashes.where('watch_list_id = ? AND hashable_type = ? AND hashable_id = ?', watchlist.id, item.class.name, item.id).empty?
    end

    private

      def get_object_key(key, parent_object_keys = [])
        parent_object_keys_string = ''
        if !parent_object_keys.empty?
          parent_object_keys_string = parent_object_keys.map{ |parent| "[#{parent}]" }.join('')
        end
        object_key = "#{@@key_prefix}#{parent_object_keys_string}[#{key}]"
      end

  end
end
