# frozen_string_literal: true

module DataCycleCore
  class Timeseries < ApplicationRecord
    self.primary_key = :thing_id
    belongs_to :thing, class_name: 'DataCycleCore::Thing'

    after_save do |item|
      item.thing.update_columns(template_updated_at: Time.zone.now)
    end

    def self.create_all(content, property, data)
      inserted = 0
      duplicates = 0
      errors = 0
      status = Status.new

      data.each do |timestamp, value|
        create!(thing_id: content.id, property: property, timestamp: timestamp, value: value)
        inserted += 1
      rescue ActiveRecord::RecordNotUnique
        duplicates += 1
        status.warning("duplicate: timestamp: #{timestamp}, value: #{value}")
      rescue ActiveRecord::NotNullViolation, ActiveRecord::RecordInvalid
        errors += 1
        status.error("wrong format for timestamp: #{timestamp}, value: #{value}.")
      end

      response = {
        meta: {
          thing_id: content.id,
          property: property,
          processed: {
            inserted: inserted,
            duplicates: duplicates,
            errors: errors
          }
        }
      }
      response[:error] = status.errors if status.error?
      response
    end

    class Status
      attr_accessor :status_hash
      TYPES = [:info, :warning, :error].freeze

      def initialize
        @status_hash = {
          info: [],
          warning: [],
          error: []
        }
      end

      def self.types
        TYPES
      end

      private

      def add_msg(msg, type)
        return false unless type.to_sym.in?(TYPES)
        status_hash[type.to_sym].push(msg)
      end

      TYPES.each do |method|                                                    # public methods!
        class_eval <<-EOM, __FILE__, __LINE__ + 1
          def #{method}(msg)                                                    # def error(msg)
            add_msg(msg, :#{method})                                            #   add_msg(msg, :error)
          end                                                                   # end

          def #{method}s                                                        # def errors
            status_hash[:#{method}]                                             #   status_hash[:error]
          end                                                                   # end

          def #{method}?                                                        # def error?
            #{method}s.size.positive?                                           #   errors.size.positive?
          end                                                                   # end
        EOM
      end
    end
  end
end
