# frozen_string_literal: true

module DataCycleCore
  class WatchList < Collection
    validates :full_path, presence: true

    has_many :watch_list_data_hashes, dependent: :delete_all
    has_many :things, through: :watch_list_data_hashes, source: :thing

    delegate :translated_locales, to: :things
    alias available_locales translated_locales

    def thing_ids
      clear_thing_cache! if watch_list_data_hashes_changed?
      @thing_ids ||= watch_list_data_hashes.pluck(:thing_id)
    end

    def reload(options = nil)
      clear_thing_cache!
      super
    end

    def self.watch_list_data_hashes
      DataCycleCore::WatchListDataHash.where(watch_list_id: pluck(:id))
    end

    def notify_subscribers(current_user, content_ids, type)
      return if content_ids.blank?

      DataCycleCore::WatchListSubscriberNotificationJob.perform_later(self, current_user, content_ids, type) if subscriptions.except_user_id(current_user.id).exists?
    end

    def self.fulltext_search(q)
      return all if q.blank?

      where('collections.full_path ILIKE ?', "%#{q}%")
    end

    def to_hash
      attributes.except('user_id')
    end

    def clear_if_not_active
      return unless my_selection && !watch_list_data_hashes.exists?(['updated_at >= ?', 12.hours.ago]) && watch_list_data_hashes.present?

      watch_list_data_hashes.clear
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id:,
        name: ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon watch_list-icon'),
          name
        ].compact, ' '),
        html_class: model_name.param_key,
        dc_tooltip: "#{model_name.human(count: 1, locale:)}: #{full_path}",
        class_key: model_name.param_key
      )
    end

    def add_things_from_query(contents_query)
      result = ActiveRecord::Base.connection.exec_query <<-SQL.squish
        INSERT INTO watch_list_data_hashes (watch_list_id, thing_id)
        #{contents_query.select("'#{id}', things.id").to_sql}
        ON CONFLICT DO NOTHING
        RETURNING thing_id;
      SQL

      update_column(:updated_at, Time.zone.now)

      result.pluck('thing_id')
    end

    def delete_all_watch_list_data_hashes
      result = ActiveRecord::Base.connection.exec_query <<-SQL.squish
        DELETE FROM watch_list_data_hashes
        WHERE watch_list_data_hashes.watch_list_id = '#{id}'
        RETURNING thing_id;
      SQL

      update_column(:updated_at, Time.zone.now)

      result.pluck('thing_id')
    end

    def update_order_by_array(order_array)
      return if order_array.blank?

      update_column(:updated_at, Time.zone.now)
      update_column(:manual_order, true) unless manual_order

      watch_list_data_hashes
        .where(thing_id: order_array)
        .update_all(['order_a = array_position(ARRAY[?]::uuid[], thing_id)', order_array])
    end

    def path
      Array.wrap(full_path_names) + [name]
    end

    private

    def clear_thing_cache!
      remove_instance_variable(:@thing_ids) if instance_variable_defined?(:@thing_ids)
    end
  end
end
