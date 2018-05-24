module DataCycleCore
  module Conversions
    def DateTime(time)
      if time.is_a?(DateTime)
        time
      elsif time.is_a?(Time)
        Time.zone.parse(time.to_s)
      elsif time.is_a?(String)
        Time.zone.parse(time)
      else
        raise TypeError("no conversion of #{time.class_name} to DateTime")
      end
    end
  end
end
