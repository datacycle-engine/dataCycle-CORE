# frozen_string_literal: true

module DataCycleCore
  class DataHashService
    extend NormalizeService

    def self.flatten_datahash_value(datahash, template_hash, debug = false)
      datahash = datahash.to_h.dc_deep_dup.with_indifferent_access

      if datahash.key?(:translations) || datahash.key?(:datahash)
        datahash[:datahash] = flatten_recursive(datahash[:datahash], template_hash)
        datahash[:translations]&.transform_values! do |locale_hash|
          flatten_recursive(locale_hash, template_hash)
        end
      else
        datahash = flatten_recursive(datahash, template_hash)
      end

      raise datahash.inspect if debug == true

      datahash
    end

    def self.flatten_datahash_translations_recursive(datahash, flatten_arrays = false)
      return datahash unless datahash.is_a?(::Hash)

      datahash = datahash.dc_deep_dup.with_indifferent_access

      if datahash.key?(:translations) || datahash.key?(:datahash)
        datahash.merge!(datahash.delete(:datahash).to_h)
        datahash.merge!(datahash.dig(:translations, I18n.locale).to_h)
        datahash.delete(:translations)
      end

      return datahash[:id] if flatten_arrays && datahash.keys.except('id').none?

      datahash.each_value do |value|
        next unless value.is_a?(::Array)

        value.map! { |v| flatten_datahash_translations_recursive(v, true) }
      end

      datahash
    end

    def self.get_internal_template(name)
      DataCycleCore::Thing.new(template_name: name)
    end

    def self.create_duplicate(content: nil, current_user: nil)
      return if content.blank? || !content.content_type?('entity')
      new_content = DataCycleCore::Thing.new(template_name: content.template_name)

      content.available_locales.each do |locale|
        I18n.with_locale(locale) do
          ActiveRecord::Base.transaction do
            created = new_content.new_record?
            new_content.save!
            new_content_datahash = content.duplicate_data_hash(content.get_data_hash).merge({ 'name': "DUPLICATE: #{content.title}" })
            valid = new_content.set_data_hash(data_hash: new_content_datahash, current_user:, new_content: created)

            raise ActiveRecord::Rollback, 'dataHash errors found' unless valid
          end
        end
      end
      return false if new_content.id.nil?
      new_content.reload
    end

    def self.get_object_params(template_name, params_hash)
      template = get_internal_template(template_name)
      schema_hash = template.schema.deep_dup
      keys = get_keys_from_hash(params_hash)
      schema_hash['properties'].slice!(*keys) if keys.present?
      get_params_from_hash(schema_hash)
    end

    def self.get_keys_from_hash(params_hash)
      keys = []
      keys.concat(params_hash[:datahash].keys) if params_hash&.[](:datahash).present?
      keys.concat(params_hash[:translations].values.map(&:keys).flatten) if params_hash&.[](:translations).present?
      keys.concat(params_hash.except(:datahash, :translations).keys) if params_hash.present?
      keys.uniq.map(&:to_s)
    end

    def self.create_internal_object(template, object_params, current_user, is_part_of = nil, source = nil)
      new_params = object_params.except(:translations, :datahash)
      if template.is_a?(DataCycleCore::ThingTemplate)
        new_params[:thing_template] = template
      elsif template.is_a?(::String)
        new_params[:template_name] = template
      end
      object = DataCycleCore::Thing.new(new_params).require_template!
      object_hash = DataCycleCore::DataHashService.flatten_datahash_value(object_params, object.schema)
      object_hash[:translations]&.deep_reject! { |_, v| v.blank? && !v.is_a?(FalseClass) }
      locale = object_hash[:translations]&.keys&.first || I18n.locale
      save_time = Time.zone.now

      DataCycleCore::Thing.transaction do
        I18n.with_locale(locale) do
          object.is_part_of = is_part_of if is_part_of.present?
          object.created_at = save_time
          object.updated_at = save_time
          object.created_by = current_user&.id
          object.save(touch: false)
        end

        next if object_hash[:datahash].blank? && object_hash[:translations].blank?

        raise ActiveRecord::Rollback unless object.set_data_hash_with_translations(
          data_hash: object_hash,
          current_user:,
          source:,
          new_content: true,
          save_time:,
          check_for_duplicates: true
        )
      end

      object
    end

    def self.get_params_from_hash(template_hash, translations = true)
      allowed_params = []

      template_hash['properties'].each do |key, value|
        if value['type'] == 'schedule'
          parameter = { key.to_sym => [datahash: [:id, :full_day, :rtimes, :extimes, start_time: [:time], duration: DataCycleCore::AttributeEditorHelper::DURATION_UNITS.keys, end_time: [:time], rrules: [:rule_type, :interval, :until, validations: [:day_of_week, :day_of_month, day: [], day_of_month: [], day_of_week: {}]]]] }
        elsif value['type'] == 'opening_time'
          parameter = { key.to_sym => [datahash: [:valid_from, :valid_until, :holiday, time: [datahash: [:id, :opens, :closes]], rrules: [validations: [day: []]]]] }
        elsif value['type'] == 'embedded'
          object_schemas = Array.wrap(value['template_name']).map { |t| get_internal_template(t).schema }
          parameter = { key.to_sym => object_schemas.map { |os| get_params_from_hash(os) }.reduce({}) { |p1, p2| p1.deep_merge(p2) { |_k, v1, v2| v1.is_a?(Array) && v2.is_a?(Array) ? (v1 + v2).uniq : v2 } } }
        elsif value['type'] == 'object' && !value['properties'].nil? && !value['properties'].empty?
          parameter = { key.to_sym => get_params_from_hash(value, false) }
        elsif value['type'] == 'classification' || value['type'] == 'linked' || value['type'] == 'collection'
          parameter = { key.to_sym => [] }
        else
          parameter = key.to_sym
        end

        allowed_params.push(parameter)
      end

      allowed_params.push(:template_name)

      return allowed_params unless translations

      { datahash: allowed_params, translations: I18n.available_locales.index_with { |_l| allowed_params } }
    end

    def self.blank?(value)
      !present?(value)
    end

    def self.present?(value)
      case value
      when FalseClass
        true
      when ActiveRecord::Relation
        value.any?
      when ::Array
        value.any? { |v| present?(v) }
      when ::Hash
        value.any? { |_, v| present?(v) }
      else
        value.present?
      end
    end

    def self.deep_blank?(value)
      blank?(value)
    end

    def self.deep_present?(value)
      present?(value)
    end

    def self.none_by_property_type(type)
      case type
      when *Content::Content::EMBEDDED_PROPERTY_TYPES, *Content::Content::LINKED_PROPERTY_TYPES
        DataCycleCore::Thing.none
      when *Content::Content::CLASSIFICATION_PROPERTY_TYPES
        DataCycleCore::Classification.none
      when *Content::Content::SCHEDULE_PROPERTY_TYPES
        DataCycleCore::Schedule.none
      when *Content::Content::TIMESERIES_PROPERTY_TYPES
        DataCycleCore::Timeseries.none
      end
    end

    def self.parse_translated_hash(datahash)
      return {} unless datahash.is_a?(::Hash)

      neutral_hash = datahash.key?(:datahash) ? datahash[:datahash].to_h : datahash.except(:translations, :version_name).to_h
      keep_locales = find_locales_recursive(neutral_hash)
      translations = datahash[:translations]&.reject { |locale, value| keep_locales.exclude?(locale) && value&.deep_reject { |_k, v| DataCycleCore::DataHashService.blank?(v) }.blank? }.presence || { I18n.locale.to_s => {} }

      translations.transform_values { |value| neutral_hash.merge(value).with_indifferent_access }
    end

    def self.find_locales_recursive(datahash, locales = [])
      datahash&.each_value do |v|
        next unless v.is_a?(::Array)

        v.each do |h|
          next unless h.is_a?(::Hash)

          find_locales_recursive(h['datahash'], locales) if h.key?('datahash')

          h['translations']&.each do |l, t|
            find_locales_recursive(t, locales)

            locales.push(l) if locales.exclude?(l) && t.deep_reject { |_tk, tv| DataCycleCore::DataHashService.blank?(tv) }.present?
          end
        end
      end

      locales
    end

    class << self
      private

      def flatten_recursive(datahash, template_hash)
        temp_datahash = {}

        datahash&.each do |key, value|
          properties = template_hash['properties'][key]
          type = properties&.dig('type')

          if value.is_a?(::Hash)
            if type == 'embedded'
              object_schemas = Array.wrap(properties['template_name']).index_with { |t| get_internal_template(t).schema }
              default_schema = object_schemas.values.first
              temp_value = []

              value.each_value do |object_value|
                if object_value.key?('datahash') || object_value.key?('translations')
                  temp_value.push(object_value.tap do |v|
                    e_schema = object_schemas[v.dig('datahash', 'template_name')] || default_schema

                    v['datahash'] = flatten_recursive(v['datahash'], e_schema)
                    v['translations'] = v['translations']&.transform_values { |t| flatten_recursive(t, e_schema) }
                  end)
                else
                  e_schema = object_schemas[object_value.dig('template_name')] || default_schema
                  temp_value.push(flatten_recursive(object_value, e_schema))
                end
              end

              value = temp_value
            elsif type == 'object'
              temp_value = {}

              value.each do |object_key, object_value|
                temp_value[object_key] = flatten_recursive({ object_key => object_value }, properties)[object_key]
              end

              value = temp_value
            elsif type == 'schedule'
              value = DataCycleCore::Schedule.to_h_from_schedule_params value
            elsif type == 'opening_time'
              value = DataCycleCore::Schedule.to_h_from_opening_time_params value
            elsif value['value'].is_a?(::Array)
              value['value'] = value['value'].reject(&:blank?)
            end
          elsif value.is_a?(::Array)
            value = value.reject(&:blank?).uniq
          elsif type == 'number' && properties.dig('validations', 'format') == 'float'
            value = value.blank? ? nil : value.to_f
          elsif type == 'number'
            value = value.blank? ? nil : value.to_i
          elsif type == 'geographic'
            if value.blank?
              value = nil
            else
              factory3d = RGeo::Cartesian.factory(srid: 4326, proj4: '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs', has_z_coordinate: true, wkt_parser: { support_wkt12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 })
              factory2d = RGeo::Cartesian.factory(srid: 4326, proj4: '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs', has_z_coordinate: false, wkt_parser: { support_wkt12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 })

              unless value.methods.include?(:geometry_type)
                geom = RGeo::GeoJSON.decode(value, geo_factory: factory3d)
                geom = RGeo::GeoJSON.decode(value, geo_factory: factory2d) if geom.geometry.geometry_type == RGeo::Feature::Point
                value = geom.geometry.as_text
              end
            end
          end

          temp_datahash[key] = value
        end

        temp_datahash
      end
    end
  end
end
