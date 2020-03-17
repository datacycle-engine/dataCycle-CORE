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
          Hash[data_hash.to_a.map { |k, v| [k.to_s.underscore, v.is_a?(Hash) ? underscore_keys(v) : v] }]
        end

        def self.strip_all(data_hash)
          Hash[data_hash.to_a.map { |k, v| [k, v.is_a?(Hash) ? strip_all(v) : (v.is_a?(String) ? v.strip : v)] }]
        end

        def self.location(data_hash)
          if data_hash['longitude'].present? && data_hash['latitude'].present?
            location = RGeo::Geographic.spherical_factory(srid: 4326).point(data_hash['longitude'].to_f, data_hash['latitude'].to_f) unless data_hash['longitude'].zero? && data_hash['latitude'].zero?
          end
          data_hash.nil? ? { 'location' => location.presence } : data_hash.merge({ 'location' => location.presence })
        end

        def self.event_schedule(data_hash, sub_event_function)
          return data_hash if data_hash.dig('event_period').blank?
          sub_event = sub_event_function.call(data_hash)
          schedule_hash = {}
          schedule_hash[:dtstart] = data_hash.dig('event_period', 'start_date')&.to_datetime
          schedule_hash[:dtend] = data_hash.dig('event_period', 'end_date')&.to_datetime
          if sub_event.present?
            rdate = sub_event.map { |i| i.dig('event_period', 'start_date')&.to_datetime || i.dig('start_date')&.to_datetime }.compact
            estart = sub_event.first.dig('event_period', 'start_date')&.to_datetime || sub_event.first.dig('start_date')&.to_datetime
            eend = sub_event.first.dig('event_period', 'end_date')&.to_datetime || sub_event.first.dig('end_date')&.to_datetime
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

        def self.tags_to_ids(data_hash, attribute, external_source_id, external_prefix)
          if data_hash[attribute].blank?
            data_hash[attribute] = []
          else
            data_hash[attribute] = data_hash[attribute].map { |keyword|
              DataCycleCore::Classification.where(
                external_source_id: external_source_id,
                external_key: external_prefix + keyword
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
                data_list.call(data_hash)&.map do |item_data|
                  search_params = {
                    external_source_id: external_source_id,
                    external_key: external_prefix + item_data.dig(key)
                  }
                  DataCycleCore::Classification.find_by(search_params)&.id
                end&.reject(&:nil?) || []
            }
          )
        end

        def self.load_category(data_hash, attribute, external_source_id, external_key)
          data_hash.merge(
            {
              attribute => [
                DataCycleCore::Classification.find_by(
                  external_source_id: external_source_id,
                  external_key: external_key.call(data_hash)
                )&.id
              ].compact.presence
            }
          )
        end

        def self.add_link(data_hash, attribute, content_type, external_source_id, key_function, condition_function = nil)
          return data_hash if condition_function.present? && !condition_function.call(data_hash)
          return data_hash if key_function.call(data_hash).blank?

          data_hash.merge(
            {
              attribute => [
                content_type.find_by(
                  external_source_id: external_source_id,
                  external_key: key_function.call(data_hash)
                )&.id
              ].compact.presence
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
              attribute =>
                content_type.where(
                  external_source_id: external_source_id,
                  external_key: key_function_values
                )&.sort_by { |u| key_function_values.index(u.external_key) }&.map(&:id)&.compact&.presence || []
            }
          )
        end

        def self.local_image(data_hash, attribute)
          return data_hash if data_hash[attribute].blank?

          begin
            asset = DataCycleCore::Image.new(remote_file_url: data_hash[attribute])
            asset.save!
            data_hash[attribute] = asset.try(:id)
          rescue StandardError => error
            logger = DataCycleCore::Generic::Logger::LogFile.new('carrierwave')
            logger.info(error, data_hash[attribute])
            logger.close
          end
          data_hash
        end

        def self.add_field(data_hash, name, function)
          data_hash.merge({ name => function.call(data_hash) })
        end
      end
    end
  end
end
