# frozen_string_literal: true

module DataCycleCore
  module UserExtensions
    module Filters
      extend ActiveSupport::Concern

      DATA_RANGE_FILTERS = ['created_at', 'updated_at'].freeze
      BOOLEAN_FILTERS = ['access_token', 'confirmed_at', 'external'].freeze
      BLOCKED_COLUMNS = ['encrypted_password', 'reset_password_token', 'current_sign_in_ip', 'last_sign_in_ip', 'provider', 'default_locale', 'type'].freeze

      included do
        scope :fulltext_search, lambda { |search_term|
          where(search_term.to_s.split.map { |term| sanitize_sql_for_conditions(["concat_ws(' ', #{search_columns.join(', ')}) ILIKE ?", "%#{term.strip}%"]) }.join(' AND '))
        }
        scope :roles, ->(value) { joins(:role).where(role: value) }
        scope :user_groups, ->(value) { joins(:user_groups).where(user_groups: { id: value }) }
        scope :date_range, lambda { |value, key|
                             from_date, to_date = DataCycleCore::Filter::Common::Date.date_from_filter_object(value, nil)
                             date_range = "[#{from_date},#{to_date}]"
                             where(sanitize_sql_for_conditions(["?::daterange @> users.#{key}::date", date_range]))
                           }
        scope :not_date_range, lambda { |value, key|
                                 from_date, to_date = DataCycleCore::Filter::Common::Date.date_from_filter_object(value, nil)
                                 date_range = "[#{from_date},#{to_date}]"
                                 where.not(sanitize_sql_for_conditions(["?::daterange @> users.#{key}::date", date_range]))
                               }

        scope :boolean, lambda { |value, key|
                          if value.to_s == 'true'
                            type_for_attribute(key).type == :boolean ? where(key.to_sym => true) : where.not(key.to_sym => nil)
                          else
                            type_for_attribute(key).type == :boolean ? where(key.to_sym => false).or(where(key.to_sym => nil)) : where(key.to_sym => nil)
                          end
                        }

        DATA_RANGE_FILTERS.each do |key|
          scope :"date_range_#{key}", ->(value) { date_range(value, key) }
          scope :"not_date_range_#{key}", ->(value) { not_date_range(value, key) }
        end

        BOOLEAN_FILTERS.each do |key|
          scope :"boolean_#{key}", ->(value) { boolean(value, key) }
          scope :"not_boolean_#{key}", ->(value) { not_boolean(value, key) }
        end
      end

      class_methods do
        def search_columns
          columns
            .select { |c| (c.type == :string && BLOCKED_COLUMNS.exclude?(c.name)) || c.name == primary_key }
            .map { |c| "users.#{c.name}" }
        end
      end
    end
  end
end
