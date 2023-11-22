# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      module Update
        include Functions

        def self.process(utility_object:, data:)
          return if data.blank?
          Functions.update(utility_object:, data:)
        end

        def self.filter(data, _external_system)
          ['Artikel'].include?(data.template_name)
        end
      end
    end
  end
end
