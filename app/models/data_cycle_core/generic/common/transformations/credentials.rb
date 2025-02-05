# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module Credentials
          def self.add_uc_credential_classifications(data_hash, external_source_id)
            return data_hash if data_hash.blank? || data_hash['dc_credential_keys'].blank?
            data_hash['universal_classifications'] ||= []
            DataCycleCore::Generic::Common::DataReferenceTransformations.add_uc_references(data_hash, external_source_id, ->(*) { data_hash['dc_credential_keys'] })
          end
        end
      end
    end
  end
end
