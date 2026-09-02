# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleApiV4
      module TransformationFunctions
        extend Dry::Transformer::Registry

        import Dry::Transformer::HashTransformations
        import Dry::Transformer::Conditional
        import Dry::Transformer::Recursion
        import DataCycleCore::Generic::Common::Functions

        SCHMEA_ORG_DAY_MAPPING = {
          'https://schema.org/Monday' => 1,
          'https://schema.org/Tuesday' => 2,
          'https://schema.org/Wednesday' => 3,
          'https://schema.org/Thursday' => 4,
          'https://schema.org/Friday' => 5,
          'https://schema.org/Saturday' => 6,
          'https://schema.org/Sunday' => 0
        }.freeze

        ERROR_KEY = 'dc_errors'
        WARNING_KEY = 'dc_warnings'
        PATH_KEY = 'dc_path'

        def self.reject_keys_by_permissions(data, template, _current_user)
          return data if data.blank?

          data.each_key do |key|
            next unless key.in?(template.property_names)
            next if key == 'external_key'
            next if [ERROR_KEY, WARNING_KEY, PATH_KEY].include?(key)
          end

          data
        end

        def self.map_linked_values(data, template, mapping_function, _external_system)
          template.linked_property_names.each do |key|
            next if data&.dig(key).blank?

            template_definition = template.properties_for(key)&.with_indifferent_access
            next if template_definition.blank?

            data[key] = Array.wrap(data[key]).each_with_index.map { |v, index|
              if v.is_a?(::String) && v.uuid?
                v
                # if linked_allowed?(template_definition, v, external_system)
                #   v
                # else
                #   data[ERROR_KEY] << { message: "The thing with id '#{v}' is not linkable for attribute '#{key.camelcase(:lower)}'", path: data[PATH_KEY] }
                #   nil
                # end
              elsif v.is_a?(::Hash)
                mapping_function.call(v, key, index)
                # if linked_allowed?(template_definition, v, external_system)
                #   mapping_function.call(v, key)
                # else
                #   data[ERROR_KEY] << { message: "The template '#{v['@type']}' is not linkable for attribute '#{key.camelcase(:lower)}'", path: data[PATH_KEY] }
                #   nil
                # end
              end
            }.compact_blank
          end

          data
        end

        # def self.linked_allowed?(template_definition, id_or_hash, external_system)
        #   template_names = Array.wrap(template_definition.dig(:template_name)).map(&:to_s).compact_blank

        #   stored_filter = template_definition.dig(:stored_filter)
        #   language = 'all'
        #   filter = DataCycleCore::StoredFilter.new.parameters_from_hash(stored_filter)
        #   filter.language = language
        #   query = filter.apply
        #   query = query.where(template_name: template_names) if template_names.present? && stored_filter.blank?

        #   if id_or_hash.is_a?(::String) && id_or_hash.uuid?
        #     id = id_or_hash
        #     thing = DataCycleCore::Thing.first_by_external_key_or_id(id, external_system.id)
        #     return true if thing.blank? # if the thing does not exist, it does not matter if it is linkable
        #     query.query.exists?(id: thing.id)
        #   elsif id_or_hash.is_a?(::Hash)
        #     hash = id_or_hash
        #     if template_names.present?
        #       template_names.include?(hash['@type'])
        #       # if keys are only @type and @id
        #     elsif hash.keys.sort == ['@id', '@type'].sort
        #       thing = DataCycleCore::Thing.first_by_external_key_or_id(hash['@id'], external_system.id)
        #       return true if thing.blank? # if the thing does not exist, it does not matter if it is linkable
        #       query.query.exists?(id: thing.id)
        #       # query.query.pluck(:template_name).uniq.include?(hash['@type']) if template_names.blank?
        #     else
        #       # a new thing will be created, so we cant really know if it is linkable here yet
        #       true
        #     end
        #   end
        # end

        def self.map_classification_values(data, template)
          classification_alias_ids = data.values_at(*template.classification_property_names).compact.flatten.uniq
          mapping = DataCycleCore::Concept.where(id: classification_alias_ids)
            .assignable
            .pluck(:id, :classification_id)
            .to_h

          template.classification_property_names.each do |key|
            next if data&.dig(key).blank?

            data[key] = Array.wrap(data[key]).map { |v| mapping[v] }.compact_blank
          end

          data
        end

        # A read renders a collection reference as { '@id' => uuid, '@type' => [..., 'dcls:WatchList'] },
        # so a push has to accept that shape back to be symmetric.
        #
        # A reference no collection matches is reported here rather than left to the validator:
        # Validators::Collection#check_reference_array compares the resolved ids against the pushed
        # ones only once at least one of them resolved, so a push of nothing but unknown ids would
        # otherwise be answered with success and no link written. An unknown reference warns, as an
        # unknown linked @id does; a property that ends up empty and is required still errors.
        def self.map_collection_values(data, template)
          template.collection_property_names.each do |key|
            references = Array.wrap(data&.dig(key)).map { |v| v.is_a?(::Hash) ? v['@id'] : v }
            next if references.blank?

            known_ids = DataCycleCore::Collection.where(id: references.select { |v| v.is_a?(::String) && v.uuid? }).pluck(:id)
            api_name = template.api_name_for(key)

            (references - known_ids).each do |reference|
              data[WARNING_KEY] << { message: "The collection with id '#{reference}' was not found for attribute '#{api_name}'", path: data[PATH_KEY] + [api_name] }
            end

            data[key] = references & known_ids
          end

          data
        end

        def self.map_embedded_values(data, template, _external_system, mapping_function)
          template.embedded_property_names.each do |key|
            next if data&.dig(key).blank?

            data[key] = Array.wrap(data[key]).each_with_index.map { |v, index|
              h = {}
              h['id'] = mapping_function.call(v, key, index)
              h.compact_blank
            }.compact_blank
          end

          data
        end

        def self.add_external_key(data, template, main_thing_id, path)
          if data['external_key'].present?
            return data
          elsif template.embedded?
            type = path.reverse.find { |element| !element.is_a?(Integer) }
            a = ['embedded', Digest::SHA1.hexdigest(data.to_json), main_thing_id, type]
            a << I18n.locale.to_s unless template.translatable_property?(type)
            data['external_key'] = a.join('_')
          else
            data['external_key'] = SecureRandom.uuid
          end

          data
        end

        def self.map_asset_values(data, template, mapping_function)
          template.asset_property_names.each do |key|
            next if data&.dig(key).blank?

            mapping_function.call(key, data)
          end

          data
        end

        def self.map_timeseries_values(data, template)
          template.timeseries_property_names.each do |key|
            next if data&.dig(key).blank?

            path = data[PATH_KEY] + [key]

            next data[ERROR_KEY] << { message: 'Invalid timeseries data, has to be a hash', path: } unless data[key].is_a?(Hash)
            next data[ERROR_KEY] << { message: 'Invalid timeseries @type, only "dc:timeseries" is allowed as @type', path: } if data[key]['@type'] != 'dc:timeseries'

            values = []

            Array.wrap(data[key]['dc:values']).each_with_index do |v, i|
              v_path = path + ['dc:values'] + [i]
              next data[WARNING_KEY] << { message: 'Invalid timeseries value, has to be a hash with "x" (timestamp) and "y" (value) or array with 2 entries ([timestamp, value])', path: v_path } if (!v.is_a?(Hash) && !v.is_a?(Array)) || (v.is_a?(Hash) && !v.key?('x') && !v.key?('y')) || (v.is_a?(Array) && v.size != 2)

              values << {
                'timestamp' => v.is_a?(Hash) ? v['x'] : v[0],
                'value' => v.is_a?(Hash) ? v['y'] : v[1]
              }
            end

            data[key] = values
          end

          data
        end

        def self.map_schedule_values(data, template, external_system)
          opening_hours_keys = template.opening_time_property_names
          template.schedule_property_names.each do |key|
            next if data&.dig(key).blank?

            data[key] = Array.wrap(data[key]).map.with_index { |v, i|
              path = data[PATH_KEY] + [key] + [i]
              if opening_hours_keys.include?(key)
                transformed_schedule = parse_opening_hours_from_schema_org(v, data, path)
                h = DataCycleCore::Generic::Common::OpeningHours.parse_opening_times(transformed_schedule, external_system.id, v['id'])&.first
              else
                h = DataCycleCore::Schedule.to_h_from_schema_org(v)
              end

              if h.blank?
                data[ERROR_KEY] << { message: 'Invalid schedule data', path: }
                next
              end

              h['external_source_id'] = external_system.id
              h['external_key'] = v['id'] || "#{key}_#{Digest::MD5.hexdigest(v.to_json)}"

              h['id'] = DataCycleCore::Schedule.first_by_external_key_or_id(*h.values_at('external_key', 'external_source_id'))&.id
              h
            }.compact_blank
          end

          data
        end

        def self.parse_opening_hours_from_schema_org(opening_hours, data, path)
          required_keys = ['opens', 'closes', 'dayOfWeek', 'validFrom', 'validThrough']
          # if opening_hours.blank? || opening_hours['opens'].blank? || opening_hours['closes'].blank? || opening_hours['dayOfWeek'].blank? || opening_hours['validFrom'].blank? || opening_hours['validThrough'].blank?
          if opening_hours.blank? || required_keys.any? { |k| opening_hours[k].blank? }
            data[ERROR_KEY] << { message: "Invalid opening hours data. Following keys are missing: #{required_keys.select { |k| opening_hours[k].blank? }.join(', ')}", path: }
            return nil
          end
          date_from = opening_hours['validFrom'] || opening_hours.dig('validFrom', '@value')
          date_to = opening_hours['validThrough'] || opening_hours.dig('validThrough', '@value')

          # reject if the date_to is in the past
          if date_to.in_time_zone < Time.zone.now
            data[ERROR_KEY] << { message: 'Invalid opening hours data. The validThrough is in the past', path: }
            return nil
          end

          opens = opening_hours['opens'] || opening_hours.dig('opens', '@value')
          closes = opening_hours['closes'] || opening_hours.dig('closes', '@value')
          week_days = Array.wrap(opening_hours['dayOfWeek']).filter_map { |d| SCHMEA_ORG_DAY_MAPPING[d] }.uniq.sort

          if date_from.blank? || date_to.blank? || opens.blank? || closes.blank? || week_days.blank? || week_days.empty?
            data[ERROR_KEY] << { message: 'Invalid opening hours data. One or more required keys are missing', path: } unless week_days.blank? || week_days.empty?
            data[ERROR_KEY] << { message: "There are no valid days in the week. Make sure to provide at least one day of the week in the format 'https://schema.org/Monday'", path: } if week_days.blank? || week_days.empty?
            return nil
          end
          if date_from.in_time_zone > date_to.in_time_zone
            data[ERROR_KEY] << { message: 'Invalid opening hours data. The validFrom is after the validThrough', path: }
            return nil
          end

          # check if the week days are in the range of the date_from and date_to
          date_range = (date_from.to_date..date_to.to_date).to_a
          week_days_in_range = date_range.map(&:wday).uniq.sort
          unless (week_days - week_days_in_range).empty?
            data[ERROR_KEY] << { message: 'Invalid opening hours data. The week days are not in the range of the validFrom and validThrough', path: }
            return nil
          end

          {
            'DateFrom' => date_from,
            'DateTo' => date_to,
            'TimeFrom' => opens,
            'TimeTo' => closes,
            'WeekDays' => week_days,
            'Holiday' => opening_hours['dayOfWeek'].include?('https://schema.org/PublicHolidays') || nil
          }
        end

        def self.map_included_values(data, template, p_mapping, mapping_function, p_mapping_function)
          included_property_names = template.included_property_names

          included_property_names.each do |key|
            # next if data&.dig(key).blank?

            # Determine if the current key has a mapping to the same value as another key
            same_value_properties = included_property_names.select { |p| p_mapping.values_at(p).uniq == p_mapping.values_at(key).uniq }
            same_value_properties = (same_value_properties + [key]).uniq

            merged_data = {}
            same_value_properties.each do |p|
              merged_data = merged_data.merge(data[p] || {})
            end

            next unless same_value_properties.any? { |p| data.key?(p) }

            # Extract and merge data for keys with the same value mapping
            property_mapping = p_mapping_function.call(template.properties_for(key)&.dig('properties'))
            data[key] ||= {}
            data[key] = if merged_data.blank?
                          nil
                        else
                          data[key].merge(mapping_function.call(merged_data, property_mapping))
                        end
          end

          data
        end

        def self.add_geo_location(data, template)
          data.delete('location') if data['location'] && !template.property?(:location)
          return data unless template.property?(:location)

          data.reject! { |k, _| k.in?(['latitude', 'longitude', 'elevation']) }
          geo = data['geo'] || {}

          if geo.key?('latitude') && geo.key?('longitude')
            latitude = geo['latitude'].presence&.to_f
            longitude = geo['longitude'].presence&.to_f

            location = RGeo::Geographic.spherical_factory(srid: 4326).point(longitude, latitude) if latitude && longitude && !(latitude.zero? && longitude.zero?)

            data['location'] = location.presence
          end

          data
        end

        def self.extract_errors_and_warnings(data, errors, warnings)
          e = data[ERROR_KEY] if data[ERROR_KEY].present?
          w = data[WARNING_KEY] if data[WARNING_KEY].present?

          errors.concat(e) if e.present?
          warnings.concat(w) if w.present?

          data.delete(ERROR_KEY)
          data.delete(WARNING_KEY)
          data
        end
      end
    end
  end
end
