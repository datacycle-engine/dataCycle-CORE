# frozen_string_literal: true

module DataCycleCore
  module DownloadHelpers
    def available_download_serializers(content)
      case content.class.to_s
      when 'DataCycleCore::WatchList'
        DataCycleCore::Feature::Download.available_collection_serializers('watch_list')
      when 'DataCycleCore::StoredFilter'
        DataCycleCore::Feature::Download.available_collection_serializers('stored_filter')
      else
        DataCycleCore::Feature::Serialize.available_serializers(content)
      end
    end

    def available_locales_for_select(content)
      available_languages = content.try(:translated_locales)&.present? ? available_locales_with_names.slice(*content.translated_locales) : available_locales_with_names
      available_languages.inject(locales_for_select = {}) { |_c, (k, v)| locales_for_select[v] = k }
      locales_for_select
    end
  end
end
