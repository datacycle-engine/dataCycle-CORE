# frozen_string_literal: true

module DataCycleCore
  # Transforms timeseries data by applying configured rules
  class TimeseriesTransformation
    def initialize(config)
      @config = config
    end

    # Applies transformation rules to timeseries data
    def apply(data)
      return data if @config.blank?

      by_key = data
        .group_by { |d| [d[:thing_id], d[:timestamp]] }
        .transform_values { |rows| rows.index_by { |r| r[:property] } }

      data.map { |point| apply_rules(point, by_key) }
    end

    private

    def apply_rules(point, by_key)
      rules = @config[point[:property]]
      return point if rules.blank?

      rules.reduce(point) do |p, rule|
        case rule['type']
        when 'zero_if' then apply_zero_if(p, rule, by_key)
        else p
        end
      end
    end

    def apply_zero_if(point, rule, by_key)
      siblings   = by_key[[point[:thing_id], point[:timestamp]]] || {}
      cond_point = siblings[rule['property']]
      return point unless cond_point

      Array(rule['values']).map(&:to_s).include?(cond_point[:value].to_s) ? point.merge(value: 0) : point
    end
  end
end
