# frozen_string_literal: true

module DataCycleCore
  module Content
    SET_DATA_HASH_ARGUMENTS = {
      data_hash: {},
      current_user: nil,
      save_time: nil,
      prevent_history: false,
      update_search_all: true,
      partial_update: true,
      partial_update_improved: DataCycleCore.partial_update_improved,
      source: nil,
      new_content: false,
      force_update: false,
      version_name: nil,
      invalidate_related_cache: true,
      check_for_duplicates: false,
      ui_locale: DataCycleCore.ui_locales.first,
      update_computed: true
    }.freeze

    DataHashOptions = Struct.new(*SET_DATA_HASH_ARGUMENTS.keys, keyword_init: true) do
      def initialize(**args)
        args[:ui_locale] = args[:current_user].ui_locale unless args[:current_user].nil?
        args.reverse_merge!(SET_DATA_HASH_ARGUMENTS)
        args[:partial_update_improved] &&= args[:partial_update]

        args[:data_hash] = args[:data_hash].dc_deep_dup.with_indifferent_access
        args[:save_time] = Time.zone.now if args[:save_time].nil?

        super(**args)
      end
    end
  end
end
