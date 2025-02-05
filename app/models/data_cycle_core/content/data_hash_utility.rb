# frozen_string_literal: true

module DataCycleCore
  module Content
    module DataHashUtility
      include DataCycleCore::NormalizeService

      # validate nil,"",[],{},[nil],[""] as blank.
      def is_blank?(data) # rubocop:disable Naming/PredicateName
        DataCycleCore::DataHashService.blank?(data)
      end

      def get_validity(validity_hash)
        from, to = get_validity_values(validity_hash)
        [
          '[',
          from.is_a?(DateTime) ? from.to_fs(:long_usec) : '',
          ',',
          to.is_a?(DateTime) ? to.to_fs(:long_usec) : '',
          ']'
        ].join
      end

      def get_validity_range(validity_hash)
        from, to = get_validity_values(validity_hash)
        ((from || Time::LONG_AGO)..(to || Float::INFINITY)) # rubocop:disable Style/RedundantParentheses
      end

      def get_validity_values(validity_hash)
        from = nil
        to = nil
        from = validity_hash['valid_from'] if validity_hash && validity_hash['valid_from']
        to = validity_hash['valid_until'] if validity_hash && validity_hash['valid_until']

        from = from.blank? ? nil : from.to_datetime&.in_time_zone&.beginning_of_day
        from = nil if from.present? && from < Time.zone.local(1980, 1, 1, 0, 0)
        to = to.blank? ? nil : to.to_datetime&.in_time_zone&.end_of_day
        to = nil if to.present? && to > Time.zone.local(9999, 1, 1, 0, 0)

        [from, to]
      end

      def name_property_selector(include_overlay = false, &)
        property_selector(include_overlay, &).keys
      end

      def property_selector(include_overlay = false)
        all_properties = property_definitions
        all_properties = all_properties.merge(add_overlay_property_definitions) if include_overlay
        all_properties.select { |_, definition| yield(definition) }
      end

      def duplicate_data_hash(data_hash)
        data_hash.deep_reject { |k, _v| k == 'id' || asset_property_names.include?(k) || computed_property_names.include?(k) }
      end
    end
  end
end
