# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for DataReferenceTransformations resolver/loader class methods: the
      # classification-uri replace branch, the unknown-reference-type raise and the
      # blank-guard / query branches of the load_* helpers (run as empty queries).
      class DataReferenceTransformationsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        Subject = DataCycleCore::Generic::Common::DataReferenceTransformations
        SYS = '00000000-0000-0000-0000-000000000000'

        test 'replace_references resolves a classification uri reference' do
          ref = Subject::ClassificationUriReference.new('tree', 'https://example.org/c#a')

          result = Subject.replace_references(ref, {}, { 'https://example.org/c#a' => 'concept-id' })

          assert_equal('concept-id', result)
        end

        test 'load_data raises for an unknown reference type' do
          assert_raises(RuntimeError) { Subject.load_data(:bogus, SYS, ['k']) }
        end

        test 'load_things returns {} for blank keys and queries otherwise' do
          assert_equal({}, Subject.load_things(SYS, []))
          assert_kind_of(Hash, Subject.load_things(SYS, ['missing-key']))
        end

        test 'load_classifications returns {} for blank keys and queries otherwise' do
          assert_equal({}, Subject.load_classifications(SYS, []))
          assert_kind_of(Hash, Subject.load_classifications(SYS, ['missing-key']))
        end

        test 'load_classifications_by_uri queries by tree and uri' do
          assert_kind_of(Hash, Subject.load_classifications_by_uri([['tree', 'https://example.org/x']]))
        end
      end
    end
  end
end
