# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DuplicateCandidate
      # Coverage for the DuplicateCandidate strategies. The Base helpers (feature /
      # to_select_option) and the OnlyNameAndLocality / ImportedDuplicate `duplicates`
      # queries are driven over content doubles; the blank guards return early and the
      # populated branch runs the real (empty) SQL and mapping.
      class UnderNinetyDuplicateCandidateCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        test 'Base exposes its feature and a select option' do
          assert_equal DataCycleCore::Feature::DuplicateCandidate, DataCycleCore::Utility::DuplicateCandidate::Base.feature
          assert_kind_of DataCycleCore::Filter::SelectOption, DataCycleCore::Utility::DuplicateCandidate::Base.to_select_option
        end

        test 'OnlyNameAndLocality#duplicates guards blank data and queries populated content' do
          blank = struct_double(name: nil, address: nil)

          assert_nil DataCycleCore::Utility::DuplicateCandidate::OnlyNameAndLocality.duplicates(content: blank)

          content = struct_double(
            name: 'Test Name',
            address: struct_double(address_locality: 'City'),
            template_name: DataCycleCore::ThingTemplate.first.template_name,
            id: SecureRandom.uuid
          )

          assert_kind_of Array, DataCycleCore::Utility::DuplicateCandidate::OnlyNameAndLocality.duplicates(content:)
        end

        test 'ImportedDuplicate#duplicates guards blank data and queries by external key' do
          blank = struct_double(external_source_id: nil, external_key: nil)

          assert_nil DataCycleCore::Utility::DuplicateCandidate::ImportedDuplicate.duplicates(content: blank)

          content = struct_double(
            external_source_id: SecureRandom.uuid,
            external_key: 'external-key-1',
            external_system_syncs: DataCycleCore::ExternalSystemSync.none,
            id: SecureRandom.uuid
          )

          assert_kind_of Array, DataCycleCore::Utility::DuplicateCandidate::ImportedDuplicate.duplicates(content:)
        end
      end
    end
  end
end
