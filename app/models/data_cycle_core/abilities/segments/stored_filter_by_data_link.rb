# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class StoredFilterByDataLink < Base
        attr_reader :subject, :types

        def initialize(types = [])
          @subject = :backend
          @types = Array.wrap(types).map(&:to_s)
        end

        def include?(_t = nil, _k = nil, filter_type = nil, *_args)
          return false unless session[:data_link_ids].present? && DataCycleCore::DataLink.where(id: session[:data_link_ids], item_type: 'DataCycleCore::StoredFilter').valid.exists?

          return true if filter_type.nil?

          @types.include?(filter_type.to_s)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
