# frozen_string_literal: true

module DataCycleCore
  module OpeningTimeHelper
    def opening_time_time_definition
      {
        'type' => 'opening_time_time',
        'label' => t('opening_time.time', locale: DataCycleCore.ui_language)
      }
    end
  end
end
