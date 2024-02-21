# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Functions
        extend Dry::Transformer::Registry

        import Dry::Transformer::ArrayTransformations
        import Dry::Transformer::HashTransformations
        import Dry::Transformer::Conditional
        import Dry::Transformer::Recursion
        import Transformations::BasicFunctions
        import Transformations::LegacyLinkFunctions
        import Transformations::RatingTransformations
        import Transformations::AdditionalInformation
        import Transformations::Schedules
        import DataReferenceTransformations

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

        def self.local_asset(data_hash, attribute, asset_type, creator_id = nil)
          return data_hash if data_hash[attribute].blank?

          begin
            asset_hash = data_hash[attribute].is_a?(::Hash) ? data_hash[attribute] : { 'remote_file_url' => data_hash[attribute] }
            asset = "DataCycleCore::#{asset_type&.classify}".safe_constantize.new(asset_hash)
            asset.name = asset_hash['file'].try(:original_filename) if asset_hash['name'].blank?
            asset.creator_id = creator_id
            asset.save!
            data_hash[attribute] = asset.try(:id)
          rescue StandardError => e
            logger = DataCycleCore::Generic::Logger::LogFile.new('asset_processing')
            logger.info(e, data_hash[attribute])
            logger.close
          end

          data_hash
        end

        def self.local_image(data_hash, attribute)
          return data_hash if data_hash[attribute].blank?

          begin
            asset = DataCycleCore::Image.new(remote_file_url: data_hash[attribute])
            asset.save!
            data_hash[attribute] = asset.try(:id)
          rescue StandardError => e
            logger = DataCycleCore::Generic::Logger::LogFile.new('asset_processing')
            logger.info(e, data_hash[attribute])
            logger.close
          end

          data_hash
        end

        def self.local_video(data_hash, attribute)
          return data_hash if data_hash[attribute].blank?

          begin
            asset = DataCycleCore::Video.new(remote_file_url: data_hash[attribute])
            asset.save!
            data_hash[attribute] = asset.try(:id)
          rescue StandardError => e
            logger = DataCycleCore::Generic::Logger::LogFile.new('asset_processing')
            logger.info(e, data_hash[attribute])
            logger.close
          end
          data_hash
        end

        def self.extension_to_mimetype(data_hash, name, function, specific_type = nil)
          extension = function.call(data_hash)

          return data_hash if extension.blank?

          data_hash.merge({ name => MiniMime.lookup_by_extension(extension.to_s)&.content_type&.then { |s| specific_type.present? ? s.gsub('application', specific_type.to_s) : s } }.compact)
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

        def self.add_external_system_data(data, name, key)
          return data if (external_name = data.dig(*Array.wrap(name))).nil? || (external_key = data.dig(*Array.wrap(key))).nil?

          data['external_system_data'] ||= []
          data['external_system_data'].push(
            {
              'identifier' => external_name,
              'external_key' => external_key,
              'sync_type' => 'duplicate'
            }
          )

          data
        end

        # split and nest data_hash into { datahash: {}, translations: {} }
        def self.json_ld_to_translated_data_hash(data_hash)
          return data_hash if data_hash.blank?

          data_hash = { datahash: data_hash, translations: {} }
          data_hash[:datahash]&.each do |key, value|
            next unless value.is_a?(::Array) && value.first.is_a?(::Hash) && value.first.key?('@language')

            while value.present?
              v = value.shift

              data_hash[:translations][v['@language']] ||= {}
              data_hash[:translations][v['@language']][key] = v['@value']
            end

            data_hash[:datahash].delete(key)
          end

          data_hash
        end
      end
    end
  end
end
