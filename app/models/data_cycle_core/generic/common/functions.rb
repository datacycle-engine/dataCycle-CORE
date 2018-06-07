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
          location = RGeo::Geographic.spherical_factory(srid: 4326).point(data_hash['longitude'].to_f, data_hash['latitude'].to_f) unless data_hash['longitude'].blank? || data_hash['latitude'].blank?
          location ||= nil
          data_hash.nil? ? { 'location' => location } : data_hash.merge({ 'location' => location })
        end

        def self.compact(data_hash)
          data_hash.compact
        end

        def self.merge(data_hash, new_hash)
          data_hash.merge(new_hash)
        end

        def self.tags_to_ids(data_hash, attribute, external_source_id, external_prefix)
          if data_hash[attribute].blank?
            data_hash[attribute] = []
          else
            data_hash[attribute] = data_hash[attribute].map { |keyword|
              DataCycleCore::Classification.where(
                name: keyword,
                external_source_id: external_source_id,
                external_key: external_prefix + keyword
              ).try(:first).try(:id)
            }.reject(&:nil?) || []
          end
          data_hash
        end

        def self.category_key_to_ids(data_hash, attribute, external_source_id, external_prefix, key)
          if data_hash[attribute].blank?
            data_hash[attribute] = []
          else
            data_hash[attribute] = data_hash[attribute].map { |item_data|
              DataCycleCore::Classification.where(
                name: item_data.dig('name'),
                external_source_id: external_source_id,
                external_key: external_prefix + item_data.dig(key)
              ).try(:first).try(:id)
            }.reject(&:nil?) || []
          end
          data_hash
        end

        def self.add_link(data_hash, attribute, content_type, external_source_id, key_function)
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

        def self.local_image(data_hash, attribute)
          return data_hash if data_hash[attribute].blank?

          asset = DataCycleCore::Image.new(remote_file_url: data_hash[attribute]).set_content_type.set_file_size
          asset.save!

          data_hash[attribute] = asset.try(:id)
          data_hash
        end

        def self.add_field(data_hash, name, function)
          data_hash.merge({ name => function.call(data_hash) })
        end
      end
    end
  end
end
