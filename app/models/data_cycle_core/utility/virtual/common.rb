# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Common
        class << self
          def copy_plain(virtual_parameters:, content:, **_args)
            content.try(virtual_parameters.first)
          end

          def take_first(virtual_parameters:, content:, **_args)
            virtual_parameters.each do |virtual_key|
              val = content.try(virtual_key.to_sym)
              return val if val.present?
            end

            nil
          end
        end
      end
    end
  end
end
