# frozen_string_literal: true

require 'hashdiff'

module DataCycleCore
  module MasterData
    module Differs
      class Schedule < UuidSet
        def diff(a, b, template, _partial_update)
          ids_a = parse_uuids(a)
          ids_b = parse_uuids(b)
          @diff_hash = (
            (set_diff(ids_a, ids_b) || []) +
            (schedule_change(a, b, template) || [])
          ).compact.presence
        end

        def schedule_change(a, b, template)
          return if a.blank? || b.blank? || template.blank?
          return if a.is_a?(ActiveRecord::Relation) && b.is_a?(ActiveRecord::Relation)
          changes = []
          a.each do |a_item|
            a_uuid = nil
            a_data = nil
            if a_item.is_a?(::Hash)
              a_uuid = a_item['id']
              a_data = a_item
            end
            if a_item.is_a?(DataCycleCore::Schedule) || a_item.is_a?(DataCycleCore::Schedule::History)
              a_uuid = a_item.id
              a_data = a_item.to_h
            end
            next if a_uuid.nil?
            b_data = find_item(b, a_uuid)
            change = diff_schedule(a_data, b_data)
            changes << a_uuid if change.present?
          end
          changes.size.positive? ? [['~', changes.sort]] : nil
        end

        def diff_schedule(a, b)
          a_hash = (a.is_a?(DataCycleCore::Schedule) || a.is_a?(IceCube::Schedule) ? a.to_h : a)&.except('relation', 'thing_id', 'dtstart', 'dtend', 'external_key', 'external_source_id')
          b_hash = (b.is_a?(DataCycleCore::Schedule) || b.is_a?(IceCube::Schedule) ? b.to_h : b)&.except('relation', 'thing_id', 'dtstart', 'dtend', 'external_key', 'external_source_id')

          @diff_hash = generic_diff(a_hash, b_hash, method(:schedule_comp).to_proc)
        end

        def schedule_comp(a, b)
          return true if a == b
          ::Hashdiff.diff(a, b).blank?
        end

        def find_item(array, uuid)
          array.each do |item|
            data = nil
            iuuid = nil
            if item.is_a?(::Hash)
              data = item
              iuuid = item['id'] || item[:id]
            end
            if item.is_a?(DataCycleCore::Schedule) || item.is_a?(DataCycleCore::Schedule::History)
              data = item.to_hash
              iuuid = item.id
            end
            next unless iuuid == uuid
            return data
          end
          nil
        end

        def parse_uuids(a)
          if a.blank?
            []
          elsif a.is_a?(::Array)
            a.filter_map do |item|
              if item.is_a?(::Hash)
                item&.dig('id') || item&.dig(:id) || "new_#{item.hash}"
              elsif item.is_a?(DataCycleCore::Schedule)
                item.id
              end
            end || []
          elsif a.is_a?(ActiveRecord::Relation)
            a.pluck(:id)
          else
            raise ArgumentError, 'Error parsing uuids. Expected data to be an Array or an ActiveRecord::Relation.'
          end
        end
      end
    end
  end
end
