# frozen_string_literal: true

module DataCycleCore
  class DataHashService
    # TODO: refactor: class => module
    extend NormalizeService

    def self.flatten_datahash_value(datahash, template_hash, debug = false)
      datahash = flatten_recursive(datahash.to_h, template_hash)

      raise datahash.inspect if debug == true

      datahash
    end

    def self.get_internal_template(name)
      DataCycleCore::Thing.find_by!(template: true, template_name: name)
    end

    def self.create_duplicate(content: nil, current_user: nil)
      return if content.blank? || !content.content_type?('entity')
      new_content = DataCycleCore::Thing.find_by(template_name: content.template_name, template: true).dup
      new_content.template = false

      content.available_locales.each do |locale|
        I18n.with_locale(locale) do
          ActiveRecord::Base.transaction do
            created = new_content.new_record?
            new_content.save!
            new_content_datahash = content.duplicate_data_hash(content.get_data_hash).merge({ 'name': "DUPLICATE: #{content.title}" })
            valid = new_content.set_data_hash(data_hash: new_content_datahash, current_user: current_user, new_content: created)
            raise ActiveRecord::Rollback, 'dataHash errors found' if valid.dig(:error).present?
          end
        end
      end
      return false if new_content.id.nil?
      new_content.reload
    end

    def self.get_object_params(template_name)
      template = get_internal_template(template_name)
      datahash = get_params_from_hash(template.schema)
      datahash
    end

    def self.create_internal_object(template_name, object_params, current_user, is_part_of = nil, source = nil)
      object = DataCycleCore::Thing.new(object_params.except(:translations))
      locale = I18n.locale
      translations = object_params[:translations]&.to_h&.deep_reject { |_, v| v.blank? && !v.is_a?(FalseClass) }
      locale = translations.keys.first if translations&.keys&.present?

      I18n.with_locale(locale) do
        template = get_internal_template(template_name)
        object.schema = template.schema
        object.template_name = template.template_name
        object.created_by = current_user&.id
        object.is_part_of = is_part_of if is_part_of.present?
        object.save
      end

      return object if object_params[:datahash].nil? && translations.nil?

      datahash = DataCycleCore::DataHashService.flatten_datahash_value((object_params[:datahash] || {}).merge(translations&.delete(locale.to_s) || {}), object.schema)
      # save_time = Time.zone.now

      I18n.with_locale(locale) do
        valid = object.set_data_hash(data_hash: datahash, current_user: current_user, prevent_history: true, source: source, new_content: true)
        if valid[:error].present?
          valid[:error].each { |k, v| v.each { |e| object.errors.add(k, e) } }
          return object
        end
      end

      translations&.each do |l, locale_hash|
        I18n.with_locale(l) do
          valid = object.set_data_hash(data_hash: locale_hash, current_user: current_user, prevent_history: true, update_search_all: false, partial_update: true)
          if valid[:error].present?
            valid[:error].each { |k, v| v.each { |e| object.errors.add(k, e) } }
            return object
          end
        end
      end

      object
    end

    def self.get_params_from_hash(template_hash)
      temp_params = []

      template_hash['properties'].each do |key, value|
        if value['type'] == 'schedule'
          key = { key.to_sym => [:id, :full_day, :rtimes, :extimes, start_time: [:time], end_time: [:time], yearly_end: [:time], rrules: [:rule_type, :interval, :until, validations: [day: []]]] }
        elsif value['type'] == 'embedded'
          object_properties = get_internal_template(value['template_name'])
          key = { key.to_sym => get_params_from_hash(object_properties.schema) }
        elsif value['type'] == 'object' && !value['properties'].nil? && !value['properties'].empty?
          key = { key.to_sym => get_params_from_hash(value) }
        elsif value['type'] == 'classification' || value['type'] == 'linked'
          key = { key.to_sym => [] }
        else
          key = key.to_sym
        end

        temp_params.push(key)
      end

      temp_params
    end

    class << self
      private

      def schedule_values(value)
        return nil if value.blank? || value.values.blank?

        value.values.map { |s|
          next nil if s.dig('start_time', 'time').blank?

          start_time = s.dig('start_time', 'time')&.in_time_zone
          end_time = s.dig('end_time', 'time')&.in_time_zone
          end_time ||= start_time if s.dig('yearly_end').blank?

          if s['full_day'] == '1'
            start_time = start_time.beginning_of_day
            s['duration'] = (end_time.beginning_of_day - start_time.beginning_of_day) + 1.day
          elsif end_time.present?
            s['duration'] = end_time - start_time
          end

          s['start_time'] = {
            time: start_time.to_s,
            zone: start_time.time_zone.name
          }

          s['rrules'][0]['until'] = s.dig('rrules', 0, 'until').in_time_zone.end_of_day if s.dig('rrules', 0, 'until').present?
          s['rrules'][0]['validations'] ||= {}
          s['rrules'][0]['validations']['hour_of_day'] = [start_time.to_datetime.hour] if s.dig('rrules', 0).present? && s.dig('yearly_end').blank?
          s['rrules'][0]['validations']['minute_of_hour'] = [start_time.to_datetime.minute] if s.dig('rrules', 0).present? && start_time.to_datetime.minute.positive?
          s['rtimes'] = s['rtimes'].presence&.split(',')&.map { |t| { time: "#{t.strip} #{start_time.to_s(:time)}".in_time_zone, zone: start_time.time_zone.name } }
          s['extimes'] = s['extimes'].presence&.split(',')&.map { |t| { time: "#{t.strip} #{start_time.to_s(:time)}".in_time_zone, zone: start_time.time_zone.name } }

          case s.dig('rrules', 0, 'rule_type')
          when 'IceCube::WeeklyRule'
            s.dig('rrules', 0, 'validations', 'day')&.map!(&:to_i)
          when 'IceCube::SingleOccurrenceRule'
            s.except!('rrules')
          when 'IceCube::YearlyRule'
            from_yday = start_time&.to_date&.yday
            to_yday = s.dig('yearly_end', 'time')&.to_date&.yday
            if to_yday.present?
              to_yday = -366 + to_yday if from_yday > to_yday
              s['rrules'][0]['validations']['day_of_year'] = [from_yday, to_yday]
            else
              s.dig('rrules', 0, 'validations')&.delete('day')
            end
          else
            s.dig('rrules', 0, 'validations')&.delete('day')
          end

          DataCycleCore::Schedule.new.from_hash(s.slice('id', 'start_time', 'duration', 'rrules', 'rtimes', 'extimes').deep_reject { |_, v| v.blank? }).to_hash.except(:relation, :thing_id).merge(id: s['id']).deep_stringify_keys.compact
        }.compact
      end

      def flatten_recursive(datahash, template_hash)
        temp_datahash = {}

        datahash.each do |key, value|
          properties = template_hash['properties'][key]
          type = properties['type'] == 'computed' ? properties.dig('compute', 'type') : properties['type']

          if value.is_a?(::Hash)

            if type == 'embedded'
              object_properties = get_internal_template(properties['template_name'])
              temp_value = []

              value.each_value do |object_value|
                temp_value.push(flatten_recursive(object_value, object_properties.schema))
              end

              value = temp_value
            elsif type == 'object'
              temp_value = {}

              value.each do |object_key, object_value|
                temp_value[object_key] = flatten_recursive({ object_key => object_value }, properties)[object_key]
              end

              value = temp_value
            elsif type == 'schedule'
              value = schedule_values value
            elsif value['value'].is_a?(::Array)
              value['value'] = value['value'].reject(&:blank?)
            end
          elsif value.is_a?(::Array)
            value = value.reject(&:blank?).uniq
          elsif type == 'number' && properties.dig('validations', 'format') == 'float'
            value = value.blank? ? nil : value.to_f
          elsif type == 'number'
            value = value.blank? ? nil : value.to_i
          end

          temp_datahash[key] = value
        end

        temp_datahash
      end
    end
  end
end
