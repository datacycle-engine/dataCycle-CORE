# frozen_string_literal: true

module DataCycleCore
  module HistoryHelper
    INDICATOR_CLASSES = {
      '+' => 'has-changes new',
      '-' => 'has-changes remove',
      '~' => 'has-changes edit'
    }.freeze

    def attribute_changes(diff, key)
      return nil if diff.blank?
      item_path_array = key.attribute_name_from_key
      diff.dig(*item_path_array)
    end

    def changes_class(diff, value)
      diff.presence&.each do |mode|
        return INDICATOR_CLASSES[mode[0]] if mode[1].presence&.include?(value)
      end
      ''
    end

    def changes_mode(diff)
      return '' if diff.blank?
      if diff.is_a?(Hash) || diff.dig(0).is_a?(Array)
        INDICATOR_CLASSES['~']
      else
        INDICATOR_CLASSES[diff.dig(0)]
      end
    end

    def changes_by_value(diff, value)
      diff.presence&.each do |mode|
        return [[mode[0], value]] if mode[1].presence&.include?(value)
      end
      nil
    end

    def changes_by_mode(diff, mode)
      diff.presence&.select { |v| v[0] == mode }&.dig(0, 1) || []
    end

    def new_relations(diff, table)
      "data_cycle_core/#{table}".classify.constantize.where(id: changes_by_mode(diff, '+'))
    end
  end
end
