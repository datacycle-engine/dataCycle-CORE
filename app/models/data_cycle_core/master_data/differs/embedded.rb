# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Embedded < Linked
        def diff(a, b, template)
          class_a = parse_uuids(a)
          class_b = parse_uuids(b)
          @diff_hash = (
            (array_diff(class_a, class_b) || []) +
            (embedded_change(a, b, template) || []) +
            (order_change(class_a, class_b) || [])
          ).compact.presence
        end

        private

        def embedded_change(a, b, template)
          return if a.blank? || b.blank? || template.blank?
          return if a.is_a?(::String) && b.is_a?(::String)
          return if a.is_a?(ActiveRecord::Relation) && b.is_a?(ActiveRecord::Relation)
          history_a = false
          history_b = false
          data_a = a
          data_b = b
          data_a = [a] if a.is_a?(::String) || a.is_a?(::Hash)
          data_b = [b] if b.is_a?(::String) || b.is_a?(::Hash)
          data_a, history_a = get_relation_ids(a) if a.is_a?(ActiveRecord::Relation)
          data_b, history_b = get_relation_ids(b) if b.is_a?(ActiveRecord::Relation)
          change = []
          data_a.each do |a_item|
            a_uuid = nil
            a_uuid = a_item if a_item.is_a?(::String)
            a_uuid = a_item.dig('id') if a_item.is_a?(::Hash)
            next if a_uuid.nil?
            b_item = find_uuid(data_b, a_uuid)
            next if b_item.nil?
            next if a_item.is_a?(::String) && b_item.is_a?(::String)
            a_content = history_a ? load_content(a_item, template, a) : load_content(a_item, template, nil)
            b_content = history_b ? load_content(b_item, template, b) : load_content(b_item, template, nil)
            changes = Differs::Object.new(a_content, b_content, load_template(template)).diff_hash
            change << a_uuid if changes.present?
          end
          change.size.positive? ? [['~', change.sort]] : nil
        end

        def find_uuid(data, uuid)
          data.each do |item|
            item_uuid = nil
            item_uuid = item if item.is_a?(::String)
            item_uuid = item.dig('id') if item.is_a?(::Hash)
            next unless item_uuid == uuid
            return item
          end
          nil
        end

        def load_template(def_hash)
          "DataCycleCore::#{def_hash.dig('linked_table').classify}"
            .constantize
            .find_by(
              template: true,
              template_name: def_hash.dig('template_name')
            )
            .schema
            .dig('properties')
        end

        def load_content(data, template, relation)
          return relation.find_by("#{template.dig('linked_table').singularize}_id".to_sym => data).get_data_hash if relation.present?
          data_hash = data.is_a?(::String) ? { 'id' => data } : data
          return data_hash if (data_hash.keys - ['id']).size.positive?
          "DataCycleCore::#{template.dig('linked_table').classify}".constantize.find(data_hash.dig('id')).get_data_hash
        end

        def parse_uuids(a)
          return if a.blank?
          data = a.deep_dup
          data = [a] if a.is_a?(::String) || a.is_a?(::Hash)
          if data.is_a?(::Array)
            data.map! { |item| item.is_a?(::Hash) ? item&.dig('id') : item }.compact || []
          end
          data, _history = get_relation_ids(a) if data.is_a?(ActiveRecord::Relation)
          raise ArgumentError, 'expected data to be converted to an array of uuids' unless data.is_a?(::Array)
          data
        end

        def get_relation_ids(a)
          history = a.klass.to_s.split('::').include?('History')
          return a.ids, history unless history
          a_id_name = (a.klass.to_s.split('::') - ['DataCycleCore', 'History']).first.tableize.singularize + '_id'
          return a.pluck(a_id_name.to_sym), history
        end
      end
    end
  end
end
