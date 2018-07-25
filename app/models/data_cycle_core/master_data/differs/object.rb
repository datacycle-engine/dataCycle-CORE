# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differ
      class Object < BasicDiffer
        def diff(a, b, template)
          template.each do |key, value|
            puts "#{key}: #{value}"
          end
          a == b
        end
      end
    end
  end
end
