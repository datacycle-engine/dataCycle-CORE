# frozen_string_literal: true

module DataCycleCore
  module PreviewHelper
    def preview_icon(key)
      icon_class = if key.include?('list')
                     'fa-list'
                   elsif key.include?('map')
                     'fa-map'
                   elsif key.include?('event')
                     'fa-calendar'
                   elsif key.include?('gallery')
                     'fa-picture-o'
                   else
                     'fa-columns'
                   end

      tag.i(class: "fa #{icon_class}")
    end
  end
end
