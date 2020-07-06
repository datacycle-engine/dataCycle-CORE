# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      module Delete
        include Functions

        def self.process(utility_object:, data:)
          return if data.blank?
          Functions.delete(utility_object: utility_object, data: data)
        end

        def self.filter(data, _external_system)
          ['Artikel'].include?(data.template_name)
        end
      end
    end
  end
end
