# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Normalizer
      module ActionParser
        class << self
          def action_type
            {
              'ADD' => :add,
              'ALTER' => :alter,
              'DELETE' => :delete,
              'SPLIT' => :split,
              'PROPOSE' => :propose,
              'ERROR' => :error
            }
          end

          def parse(normalize_report)
            actions = []
            normalize_report.dig('actionList').each do |action|
              raise ArgumentError, "Unknown taskType: #{action.dig('taskType')} | known types: #{action_type.keys}" unless action_type.key?(action.dig('taskType'))
              entry = send(action_type[action['taskType']], action)
              actions << entry if entry.present?
            end
            consolidate(actions.flatten)
          end

          def add(action)
            action
              .dig('fieldsAfter')
              .map { |item| { item['id'] => ['+', item['content']] } }
          end

          def alter(action)
            action
              .dig('fieldsAfter')
              .zip(action.dig('fieldsBefore'))
              .map { |after, before| { after['id'] => ['~', after['content'], before['content']] } }
          end

          def delete(action)
            action
              .dig('fieldsBefore')
              .filter_map { |item| item['content'].blank? ? nil : { item['id'] => ['-', item['content']] } }
          end

          def split(action)
            return if action['taskId'] == 'Split_StreetStreetnr'
            action
              .dig('fieldsAfter')
              .product(action.dig('fieldsBefore'))
              .map do |after, before|
                if after.dig('id') == before.dig('id')
                  { after['id'] => ['~', after['content'], before['content']] }
                else
                  { after['id'] => ['+', after['content']] }
                end
              end
          end

          def propose(action)
            [{
              action.dig('fieldsProposed').first.dig('id') =>
                ['?', action.dig('fieldsProposed').pluck('content')]
            }]
          end

          def error(action)
            [{ 'ERROR' => ['!', action['message']] }]
          end

          def consolidate(diffs)
            diffs.reduce({}) { |hash, item| hash.merge(item) { |_key, old_val, new_val| old_val[0].is_a?(::String) ? [old_val] + [new_val] : old_val << new_val } }
          end
        end
      end
    end
  end
end
