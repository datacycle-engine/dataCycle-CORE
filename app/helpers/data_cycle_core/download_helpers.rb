# frozen_string_literal: true

module DataCycleCore
  module DownloadHelpers
    def available_download_serializers(content, scope = [:content])
      DataCycleCore::Feature::Download.enabled_serializers_for_download(content, scope)
    end

    def available_locales_for_select(content)
      available_languages = content.try(:translated_locales).present? ? available_locales_with_names.slice(*content.translated_locales.map(&:to_sym)) : available_locales_with_names
      available_languages.inject(locales_for_select = {}) { |_c, (k, v)| locales_for_select[v] = k }
      locales_for_select
    end
  end
end
