# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      module Transformations
        def self.t(*args)
          DataCycleCore::Export::Onlim::TransformationFunctions[*args]
        end

        def self.blacklist
          {
            'PostalAddress' => ['telephone', 'faxNumber', 'email', 'url']
          }
        end

        def self.to_poi
          t(:context_to_onlim)
          .>> t(:remove_namespaced_data)
          .>> t(:remove_thing_stubs)
          .>> t(:type_to_onlim)
          .>> t(:apply_full_blacklist, blacklist)
          .>> t(:strip_all)
        end
      end
    end
  end
end
