# frozen_string_literal: true

module DataCycleCore
  class Activity < ApplicationRecord
    belongs_to :user
    belongs_to :activitiable, polymorphic: true

    def self.activity_list
      select(:activity_type).group(:activity_type).pluck(:activity_type)
    end

    def self.activity_stats(from = nil, to = Time.zone.now)
      from ||= Time::LONG_AGO
      select(:activity_type, 'count(activity_type) as data_count')
        .where({ created_at: from..to })
        .group(:activity_type)
        .order('data_count DESC')
    end

    def self.activities_by_user(user_id, from = nil, to = Time.zone.now)
      raise ArgumentError if user_id.blank?
      users = Array.wrap(user_id)
      from ||= Time::LONG_AGO
      select(:activity_type, 'count(activity_type) as data_count')
        .where(user_id: users)
        .where({ created_at: from..to })
        .group(:activity_type)
        &.map { |item| { item.activity_type => item.data_count } }
        &.inject(&:merge)
    end

    def self.user_doing_activity(activity, from = nil, to = Time.zone.now)
      raise ArgumentError if activity.blank?
      from ||= Time::LONG_AGO
      select(:activity_type, :user_id, 'count(user_id) as data_count')
        .where(activity_type: activity)
        .where({ created_at: from..to })
        .group(:activity_type, :user_id)
        &.map { |item| { item.user_id => item.data_count } }
        &.inject(&:merge)
    end

    def self.activities_user_overview(from = nil, to = Time.zone.now)
      from ||= Time::LONG_AGO
      select(:activity_type, :user_id, :email, 'count(user_id) as data_count')
        .where({ created_at: from..to })
        .joins(:user)
        .group(:user_id, :email, :activity_type)
        .order('data_count DESC')
    end

    def self.activity_details(from = nil, to = Time.zone.now)
      from ||= Time::LONG_AGO
      select(
        :activity_type,
        :user_id,
        :email,
        'count(user_id) as data_count',
        'MAX(activities.created_at) as last_request',
        'activities.data->>\'action\' as request_action',
        'activities.data->>\'controller\' as request_controller',
        'activities.data->>\'type\' as request_type',
        'activities.data->>\'include\' as request_include',
        'activities.data->>\'fields\' as request_fields',
        'activities.data->>\'mode\' as request_mode',
        'activities.data->>\'filter\' as request_filter',
        'activities.data->>\'page\' as request_page',
        'activities.data->>\'id\' as request_id',
        'activities.data->>\'referer\' as request_referer',
        'activities.data->>\'origin\' as request_origin',
        'activities.data->>\'middlewareOrigin\' as request_middleware_origin'
      )
        .where({ created_at: from..to })
        .joins(:user)
        .group('request_controller', 'request_action', 'request_type', 'request_include', 'request_fields', 'request_filter', 'request_page', 'request_mode', 'request_id', 'request_referer', 'request_origin', 'request_middleware_origin', :user_id, :email, :activity_type)
        .order('data_count DESC')
    end
  end
end
