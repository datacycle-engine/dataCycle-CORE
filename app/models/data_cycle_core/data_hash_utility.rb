# frozen_string_literal: true

module DataCycleCore
  module DataHashUtility
    # validate nil,"",[],{},[nil],[""] as blank.
    def is_blank?(data)
      return true if data.blank?
      if data.is_a?(::Array)
        return true if data.length == 1 && data[0].blank?
      end
      false
    end

    def get_validity(validity_hash)
      from, to = get_validity_values validity_hash
      [
        '[',
        from.is_a?(DateTime) ? from.to_s(:long_usec) : '',
        ',',
        to.is_a?(DateTime) ? to.to_s(:long_usec) : '',
        ']'
      ].join('')
    end

    def get_validity_values(validity_hash)
      # TODO: check for expires and publish_at usage
      from = nil
      to = nil
      from = validity_hash['valid_from'] if validity_hash && validity_hash['valid_from']
      to = validity_hash['valid_until'] if validity_hash && validity_hash['valid_until']

      from = from.blank? ? nil : from.to_datetime
      from = nil if from.present? && from < Time.zone.local(1980, 1, 1, 0, 0)
      to = to.blank? ? nil : to.to_datetime
      to = nil if to.present? && to > Time.zone.local(9999, 1, 1, 0, 0)

      [from, to]
    end
  end
end
