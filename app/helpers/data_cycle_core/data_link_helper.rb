# frozen_string_literal: true

module DataCycleCore
  module DataLinkHelper
    def data_link_modes(content)
      modes = [OpenStruct.new(type: :read)]

      modes.push(OpenStruct.new(type: :write)) if can?(:create_editable_links, DataCycleCore::DataLink) &&
                                                  (
                                                    (
                                                      content.is_a?(DataCycleCore::WatchList) &&
                                                      content.try(:things)&.all? { |thing| can?(:edit, thing) } &&
                                                      can?(:add_item, content)
                                                    ) ||
                                                    can?(:edit, content)
                                                  )

      modes.unshift(OpenStruct.new(type: :download)) if (
        content.is_a?(DataCycleCore::WatchList) && can?(:download_zip, content)
      ) || (
        content.is_a?(DataCycleCore::Thing) && can?(:download, content)
      )

      modes
    end
  end
end
