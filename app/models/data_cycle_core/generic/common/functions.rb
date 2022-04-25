# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Functions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion

        def self.underscore_keys(data_hash)
          data_hash.to_h.deep_transform_keys { |k| k.to_s.underscore }
        end

        def self.strip_all(data_hash)
          data_hash.to_h.deep_transform_values { |v| v.is_a?(::String) ? v.strip : v }
        end

        def self.location(data_hash)
          location = RGeo::Geographic.spherical_factory(srid: 4326).point(data_hash['longitude'].to_f, data_hash['latitude'].to_f) if data_hash['longitude'].present? && data_hash['latitude'].present? && !(data_hash['longitude'].zero? && data_hash['latitude'].zero?)
          data_hash.nil? ? { 'location' => location.presence } : data_hash.merge({ 'location' => location.presence })
        end

        def self.event_schedule(data_hash, sub_event_function)
          return data_hash if data_hash.dig('event_period').blank?
          sub_event = sub_event_function.call(data_hash)
          schedule_hash = {}
          schedule_hash[:dtstart] = data_hash.dig('event_period', 'start_date')&.in_time_zone
          schedule_hash[:dtend] = data_hash.dig('event_period', 'end_date')&.in_time_zone
          if sub_event.present?
            rdate = sub_event.map { |i| i.dig('event_period', 'start_date')&.in_time_zone || i.dig('start_date')&.in_time_zone }.compact
            estart = sub_event.first.dig('event_period', 'start_date')&.in_time_zone || sub_event.first.dig('start_date')&.in_time_zone
            eend = sub_event.first.dig('event_period', 'end_date')&.in_time_zone || sub_event.first.dig('end_date')&.in_time_zone
            duration = eend.to_i - estart.to_i if eend.present? && estart.present?
            options = { duration: duration.presence&.to_i }.compact
            schedule_object = IceCube::Schedule.new(schedule_hash[:dtstart].in_time_zone.presence || Time.zone.now, options) do |s|
              rdate.sort.each do |rd|
                s.add_recurrence_time(rd.in_time_zone)
              end
            end
            schedule_hash[:duration] = duration if duration.present?
            schedule_hash = schedule_hash.merge(schedule_object.to_hash)
          elsif schedule_hash[:dtend].present? && schedule_hash[:dtstart].present?
            schedule_hash[:duration] = schedule_hash[:dtend].to_i - schedule_hash[:dtstart].to_i
            schedule_hash[:start_time] = {
              time: schedule_hash[:dtstart],
              zone: Time.zone.name
            }
            schedule_hash[:end_time] = {
              time: schedule_hash[:dtend],
              zone: Time.zone.name
            }
          end
          (data_hash || {}).merge({ 'event_schedule' => Array.wrap(schedule_hash.with_indifferent_access) })
        end

        def self.compact(data_hash)
          data_hash.compact
        end

        def self.merge(data_hash, new_hash)
          data_hash.merge(new_hash)
        end

        def self.merge_array_values(data_hash, key, merge_key)
          data_hash[key] = Array(data_hash[key]) | Array(data_hash[merge_key])
          data_hash
        end

        def self.tags_to_ids(data_hash, attribute, external_source_id, external_prefix, condition_function = nil)
          return data_hash if condition_function.present? && !condition_function.call(data_hash)

          if data_hash[attribute].blank?
            data_hash[attribute] = []
          else
            data_hash[attribute] = data_hash[attribute].map { |keyword|
              DataCycleCore::Classification.where(
                external_source_id: external_source_id,
                external_key: external_prefix.to_s + keyword.to_s
              )&.first&.id
            }.reject(&:nil?) || []
          end
          data_hash
        end

        def self.tags_to_ids_by_name(data_hash, attribute, tree_label)
          if data_hash[attribute].blank?
            data_hash[attribute] = []
          else
            data_hash[attribute] = DataCycleCore::Classification.includes(primary_classification_alias: [classification_tree: :classification_tree_label]).where('lower(classifications.name) IN (?)', data_hash[attribute]&.map(&:downcase)).where(primary_classification_alias: { classification_trees: { classification_tree_labels: { name: tree_label } } }).ids
          end
          data_hash
        end

        def self.category_key_to_ids(data_hash, attribute, data_list, _name, external_source_id, external_prefix, key)
          return data_hash if data_hash.blank? || data_list.blank?

          data_hash.merge(
            {
              attribute =>
                data_list.call(data_hash)&.map { |item_data|
                  search_params = {
                    external_source_id: external_source_id,
                    external_key: external_prefix + item_data.dig(key)
                  }
                  DataCycleCore::Classification.find_by(search_params)&.id
                }&.reject(&:nil?) || []
            }
          )
        end

        def self.load_category(data_hash, attribute, external_source_id, external_key)
          data_hash.merge(
            {
              attribute => [
                DataCycleCore::Classification.find_by(
                  external_source_id: external_source_id, external_key: external_key.call(data_hash)
                )&.id
              ].compact.presence
            }
          )
        end

        def self.add_link(data_hash, attribute, content_type, external_source_id, key_function, condition_function = nil)
          return data_hash if condition_function.present? && !condition_function.call(data_hash)

          data_hash.merge(
            {
              attribute => find_thing_ids(external_system_id: external_source_id, external_key: key_function.call(data_hash), content_type: content_type, limit: 1).presence
            }
          )
        end

        def self.add_user_link(data_hash, attribute, key_function)
          return data_hash if key_function.call(data_hash).blank?
          data_hash.merge({ attribute => DataCycleCore::User.find_by(email: key_function.call(data_hash))&.id })
        end

        def self.add_links(data_hash, attribute, content_type, external_source_id, key_function, condition_function = nil)
          return data_hash if condition_function.present? && !condition_function.call(data_hash)

          key_function_values = key_function.call(data_hash) || []
          # key_function_values = [DataCycleCore::Thing.where(external_source_id: external_source_id, template: false, template_name: 'POI').first.external_key] if attribute == 'poi'

          data_hash.merge(
            {
              attribute => find_thing_ids(external_system_id: external_source_id, external_key: key_function_values, content_type: content_type)
            }
          )
        end

        def self.local_image(data_hash, attribute)
          return data_hash if data_hash[attribute].blank?

          begin
            asset = DataCycleCore::Image.new(remote_file_url: data_hash[attribute])
            asset.save!
            data_hash[attribute] = asset.try(:id)
          rescue StandardError => e
            logger = DataCycleCore::Generic::Logger::LogFile.new('carrierwave')
            logger.info(e, data_hash[attribute])
            logger.close
          end
          data_hash
        end

        def self.add_field(data_hash, name, function)
          data_hash.merge({ name => function.call(data_hash) })
        end

        def self.extension_to_mimetype(data_hash, name, function, specific_type = nil)
          extension = function.call(data_hash)

          return data_hash if extension.blank?

          data_hash.merge({ name => MiniMime.lookup_by_extension(extension.to_s)&.content_type&.then { |s| specific_type.present? ? s.gsub('application', specific_type.to_s) : s } }.compact)
        end

        def self.universal_classifications(data_hash, function)
          data_hash['universal_classifications'] ||= []
          data_hash['universal_classifications'] += (function.call(data_hash) || [])
          data_hash
        end

        def self.geocode(data_hash, condition_function = nil)
          return data_hash unless DataCycleCore::Feature::Geocode.enabled?
          return data_hash if condition_function.present? && !condition_function.call(data_hash)

          address_params = data_hash.dig(DataCycleCore::Feature::Geocode.address_source)
          return data_hash if address_params.blank? || address_params.values.all?(&:blank?)

          begin
            geocoded_data = DataCycleCore::Feature::Geocode.geocode_address(address_params.to_h)
          rescue DataCycleCore::Generic::Common::Error::EndpointError => e
            geocoded_data = OpenStruct.new(error: e.message)
          end

          if geocoded_data.try(:error).present?
            logger = DataCycleCore::Generic::Logger::LogFile.new('geocode')
            logger.info(geocoded_data.error)
            logger.close
            return data_hash
          end

          attributes = DataCycleCore::Feature::Geocode.geodata_to_attributes(geocoded_data)
          data_hash.merge(attributes.deep_stringify_keys)
        end

        def self.find_thing_ids(external_system_id:, external_key:, content_type: DataCycleCore::Thing, limit: nil, pluck_id: true)
          return [] if external_key.blank?

          if content_type == DataCycleCore::Thing
            query = DataCycleCore::Thing
              .by_external_key(external_system_id, external_key, 'thing_external_systems')
              .order(
                [
                  Arel.sql(
                    'array_position(ARRAY[?]::varchar[], thing_external_systems.external_key::varchar)'
                  ),
                  external_key
                ]
              )
          else
            query = content_type.where(external_source_id: external_system_id, external_key: external_key).order(
              [
                Arel.sql("array_position(ARRAY[?]::varchar[], #{content_type.table_name}.external_key::varchar)"),
                external_key
              ]
            )
          end

          query = query.limit(limit) if limit.present?
          query = query.pluck(:id) if pluck_id
          query
        end
      end
    end
  end
end
