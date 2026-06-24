# frozen_string_literal: true

module DataCycleCore
  class DataHashService
    extend NormalizeService

    ARRAY_PROPERTY_TYPES = ['classification', 'linked', 'collection'].freeze
    SCHEDULE_PARAMS = [{ datahash: [:id, :full_day, :rtimes, :extimes, { start_time: [:time], duration: DataCycleCore::AttributeEditorHelper::DURATION_UNITS.keys, end_time: [:time], rrules: [:rule_type, :interval, :until, { validations: [:day_of_week, :day_of_month, { day: [], day_of_month: [], day_of_week: {} }] }] }] }].freeze
    OPENING_TIME_PARAMS = [{ datahash: [:valid_from, :valid_until, :holiday, { time: [{ datahash: [:id, :opens, :closes] }], rrules: [{ validations: [{ day: [] }] }] }] }].freeze

    attr_accessor :template_cache

    def initialize
      @template_cache = {}
    end

    def permitted_content_params(template_name_or_schema, params)
      return ActionController::Parameters.new.permit if params.blank? || template_name_or_schema.blank?

      if template_name_or_schema.is_a?(String)
        template = get_internal_template(template_name_or_schema)
        template_hash = template.schema.deep_dup
      elsif template_name_or_schema.is_a?(::Hash)
        template_hash = template_name_or_schema.deep_dup
      else
        return ActionController::Parameters.new.permit
      end

      permit_content_hash(template_hash, params, true)
    end

    def permit_content_hash(template_hash, params, translations = true)
      return ActionController::Parameters.new.permit unless params.is_a?(ActionController::Parameters) && template_hash.is_a?(::Hash)

      permitted = params.permit(:template_name, :version_name)
      permitted_datahash = permit_content_hash(template_hash, params[:datahash], translations)
      permitted[:datahash] = permitted_datahash if params.key?(:datahash)

      permitted_translations = ActionController::Parameters.new.permit
      params[:translations]&.each do |key, value|
        permitted_translations[key.to_sym] = permit_content_hash(template_hash, value, translations)
      end
      permitted[:translations] = permitted_translations if params.key?(:translations)

      params.except(:datahash, :translations)&.each_key do |k|
        permitted.merge!(permit_param_for_prop(params, k, template_hash))
      end

      permitted
    end

    def permit_param_for_prop(params, key, template_hash)
      prop = template_hash['properties'][key.to_s]
      return if prop.nil? || prop.key?('compute') || prop.key?('virtual')

      if prop['type'] == 'schedule'
        params.permit({ key.to_sym => SCHEDULE_PARAMS })
      elsif prop['type'] == 'opening_time'
        params.permit({ key.to_sym => OPENING_TIME_PARAMS })
      elsif prop['type'] == 'embedded'
        embedded_params = ActionController::Parameters.new.permit
        permitted_embedded = ActionController::Parameters.new.permit
        if params[key].is_a?(ActionController::Parameters)
          params[key]&.each do |index, value|
            next unless value.is_a?(ActionController::Parameters)

            template_name = value[:template_name].presence || value.dig(:datahash, :template_name)
            embedded_schema = get_internal_template(template_name).schema
            permitted_embedded[index] = permit_content_hash(embedded_schema, value, true)
          end
        elsif params[key].is_a?(::Array) # used in tests and possibly other places
          params[key].each_with_index do |value, index|
            next unless value.is_a?(ActionController::Parameters)

            template_name = value[:template_name].presence || value.dig(:datahash, :template_name)
            embedded_schema = get_internal_template(template_name).schema
            permitted_embedded[index] = permit_content_hash(embedded_schema, value, true)
          end
        end
        embedded_params[key.to_sym] = permitted_embedded
        embedded_params
      elsif prop['type'] == 'object' && prop['properties'].present?
        object_params = ActionController::Parameters.new.permit
        object_params[key.to_sym] = permit_content_hash(prop, params[key], false)
        object_params
      elsif ARRAY_PROPERTY_TYPES.include?(prop['type'])
        params.permit({ key.to_sym => [] })
      else
        params.permit(key.to_sym)
      end
    end

    def self.flatten_datahash_value(datahash, template_hash, debug = false)
      datahash = datahash.to_h.dc_deep_dup.with_indifferent_access
      template_cache = {}

      if datahash.key?(:translations) || datahash.key?(:datahash)
        datahash[:datahash] = flatten_recursive(datahash[:datahash], template_hash, template_cache)
        datahash[:translations]&.transform_values! do |locale_hash|
          flatten_recursive(locale_hash, template_hash, template_cache)
        end
      else
        datahash = flatten_recursive(datahash, template_hash, template_cache)
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

    def self.get_internal_template(name, template_cache = {})
      t_names = Array.wrap(name)
      missing = t_names - template_cache.keys

      if missing.present?
        missing_templates = DataCycleCore::ThingTemplate.where(template_name: missing).index_by(&:template_name)
        missing.each do |tn|
          template_cache[tn] = DataCycleCore::Thing.new(thing_template: missing_templates[tn])
        end
      end

      name.is_a?(::Array) ? template_cache.values_at(*t_names) : template_cache[name]
    end

    def get_internal_template(name)
      self.class.get_internal_template(name, template_cache)
    end

    def self.create_internal_object(template, object_params, current_user, is_part_of = nil, source = nil)
      new_params = object_params.except(:translations, :datahash)
      if template.is_a?(DataCycleCore::ThingTemplate)
        new_params[:thing_template] = template
      elsif template.is_a?(::String)
        new_params[:template_name] = template
      end
      object = DataCycleCore::Thing.new(new_params)
      object_hash = DataCycleCore::DataHashService.flatten_datahash_value(object_params, object.schema)
      object_hash[:translations]&.deep_reject! { |_, v| v.blank? && !v.is_a?(FalseClass) }
      locale = object_hash[:translations]&.keys&.first || I18n.locale
      save_time = Time.zone.now

      DataCycleCore::Thing.transaction do
        I18n.with_locale(locale) do
          object.is_part_of = is_part_of if is_part_of.present?
          object.created_at = save_time
          object.updated_at = save_time
          object.cache_valid_since = save_time
          object.created_by = current_user&.id
          object.last_updated_locale = locale
          object.save(touch: false)
        end

        next if object_hash[:datahash].blank? && object_hash[:translations].blank?

        raise ActiveRecord::Rollback unless object.set_data_hash_with_translations(
          data_hash: object_hash,
          current_user:,
          source:,
          new_content: true,
          save_time:
        )
      end

      object
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

    def self.parse_translated_hash(datahash, allowed_locales = [], reject_blank = true)
      return {} unless datahash.is_a?(::Hash)

      neutral_hash = datahash.key?(:datahash) ? datahash[:datahash].to_h : datahash.except(:translations, :version_name).to_h
      keep_locales = (find_locales_recursive(neutral_hash, [], reject_blank) + allowed_locales.map(&:to_s)).uniq

      translations = if reject_blank
                       datahash[:translations]&.reject { |locale, value| keep_locales.exclude?(locale) && value&.deep_reject { |_k, v| DataCycleCore::DataHashService.blank?(v) }.blank? }.presence || { I18n.locale.to_s => {} }
                     else
                       datahash[:translations]&.slice(*keep_locales).presence || { I18n.locale.to_s => {} }
                     end

      translations.transform_values { |value| neutral_hash.merge(value).with_indifferent_access }
    end

    def self.normalize_datahash(data)
      return if data.blank? && data != false

      if data.is_a?(::Hash) && (data.key?('translations') || data.key?('datahash'))
        d2 = data.dc_deep_dup.with_indifferent_access
        d2['datahash']&.transform_values! { |v| normalize_datahash(v) }
        d2['translations']&.transform_values! do |locale_hash|
          locale_hash.transform_values { |v| normalize_datahash(v) }
        end
        d2
      elsif data.is_a?(::Hash)
        data.transform_values { |v| normalize_datahash(v) }.presence
      elsif data.is_a?(::Array)
        data.map { |v| normalize_datahash(v) }.presence
      else
        data.present? || data == false ? data : nil
      end
    end

    def self.find_locales_recursive(datahash, locales = [], reject_blank = true)
      return locales unless datahash.is_a?(::Hash)

      datahash&.each_value do |v|
        next unless v.is_a?(::Array)

        v.each do |h|
          next unless h.is_a?(::Hash)

          find_locales_recursive(h['datahash'], locales, reject_blank) if h.key?('datahash')

          h['translations']&.each do |l, t|
            find_locales_recursive(t, locales, reject_blank)

            locales.push(l) if locales.exclude?(l) && (!reject_blank || t.deep_reject { |_tk, tv| DataCycleCore::DataHashService.blank?(tv) }.present?)
          end
        end
      end

      locales
    end

    class << self
      private

      def flatten_recursive(datahash, template_hash, template_cache = {})
        temp_datahash = {}

        datahash&.each do |key, value|
          properties = template_hash['properties'][key]
          type = properties&.dig('type')

          if value.is_a?(::Hash)
            if type == 'embedded'
              temp_value = []

              value.each_value do |object_value|
                if object_value.key?('datahash') || object_value.key?('translations')
                  temp_value.push(object_value.tap do |v|
                    e_schema = get_internal_template(v.dig('datahash', 'template_name'))&.schema

                    v['datahash'] = flatten_recursive(v['datahash'], e_schema, template_cache)
                    v['translations'] = v['translations']&.transform_values { |t| flatten_recursive(t, e_schema, template_cache) }
                  end)
                else
                  e_schema = get_internal_template(object_value['template_name'])&.schema
                  temp_value.push(flatten_recursive(object_value, e_schema, template_cache))
                end
              end

              value = temp_value
            elsif type == 'object'
              temp_value = {}

              value.each do |object_key, object_value|
                temp_value[object_key] = flatten_recursive({ object_key => object_value }, properties, template_cache)[object_key]
              end

              value = temp_value
            elsif type == 'schedule'
              value = DataCycleCore::Schedule.to_h_from_schedule_params value
            elsif type == 'opening_time'
              value = DataCycleCore::Schedule.to_h_from_opening_time_params value
            elsif value['value'].is_a?(::Array)
              value['value'] = value['value'].compact_blank
            end
          elsif value.is_a?(::Array)
            value = value.compact_blank.uniq
          elsif type == 'number' && properties.dig('validations', 'format') == 'float'
            value = value.presence&.to_f
          elsif type == 'number'
            value = value.presence&.to_i
          elsif type == 'boolean'
            value = blank?(value) ? nil : value == 'true'
          elsif type == 'table'
            value = JSON.parse(value) rescue nil # rubocop:disable Style/RescueModifier
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
