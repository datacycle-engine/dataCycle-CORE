# frozen_string_literal: true

class TimeHelper
  class << self
    def format_time(time, n, m, unit)
      time.round(m).to_s.split('.').zip([->(x) { x.rjust(n) }, ->(x) { x.ljust(m, '0') }]).map { |x, f| f.call(x) }.join('.') + " #{unit}"
    end
  end
end
