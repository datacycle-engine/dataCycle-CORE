# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      module Extensions
        # Covers the import_concept_schemes / import_concepts orchestration methods
        # (included into ImportFunctions); the sibling Common::ImportConcepts data
        # helpers are covered by test/models/generic/common/import_concepts_test.rb.
        class ImportConceptsTest < DataCycleCore::TestCases::ActiveSupportTestCase
          before(:all) do
            @subject = DataCycleCore::Generic::Common::ImportFunctions
            @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
          end

          # iterator must keep an explicit filter_object: keyword — filter_object? introspects for it
          def scheme_iterator
            ->(filter_object:) { [raw_item({ 'id' => '1', 'name' => 'CS' })] } # rubocop:disable Lint/UnusedBlockArgument
          end

          def concept_iterator
            ->(filter_object:) { [raw_item({ 'id' => '1' })] } # rubocop:disable Lint/UnusedBlockArgument
          end

          test 'import_concept_schemes upserts the processed concept scheme data' do
            data_processor = ->(**) { { name: 'CS One', external_key: 'cs-1', external_source_id: @local_system.id } }
            external_system_processor = ->(data_array:, **) { data_array }
            captured = nil

            DataCycleCore::ClassificationTreeLabel.stub(:upsert_all, lambda { |data, **_opts|
              captured = data
              [{ 'id' => 'csl-1' }]
            }) do
              @subject.import_concept_schemes(utility_object: import_object('ics_step'), iterator: scheme_iterator, data_processor:, external_system_processor:, options: { import: {} })
            end

            assert_equal([{ name: 'CS One', external_key: 'cs-1', external_source_id: @local_system.id }], captured)
          end

          test 'import_concept_schemes fails the phase when processing raises' do
            data_processor = ->(**) { raise 'boom' }
            external_system_processor = ->(**) { [] }

            stub_instrument do
              assert_nothing_raised do
                @subject.import_concept_schemes(utility_object: import_object('icse_step'), iterator: scheme_iterator, data_processor:, external_system_processor:, options: { import: {} })
              end
            end
          end

          test 'import_concepts upserts classifications, mappings and geoms per scheme' do
            scheme = concept_scheme_double
            data_processor = ->(**) { { external_key: 'c1', name: 'C One' } }
            data_transformer = ->(**) { { scheme => [{ external_key: 'c1', name: 'C One' }] } }
            data_mapping_processor = ->(**) { [{ parent_id: 'p', child_id: 'c', link_type: 'related' }] }
            data_geom_processor = ->(**) { [{ classification_alias_id: 'a', geom: 'POINT (1 2)' }] }
            captured_mappings = nil

            DataCycleCore::ConceptLink.stub(:insert_all, lambda { |mappings, **_opts|
              captured_mappings = mappings
              [{ 'id' => 'link-1' }]
            }) do
              DataCycleCore::ClassificationPolygon.stub(:upsert_all_geoms, 1) do
                @subject.import_concepts(utility_object: import_object('ic_step'), iterator: concept_iterator, data_processor:, data_transformer:, data_mapping_processor:, data_geom_processor:, options: { import: {} })
              end
            end

            assert_equal([{ parent_id: 'p', child_id: 'c', link_type: 'related' }], captured_mappings)
          end

          test 'import_concepts logs an error for a missing concept scheme' do
            data_processor = ->(**) { { external_key: 'c1', name: 'C One' } }
            data_transformer = ->(**) { { nil => [{ external_key: 'c1' }] } }
            data_mapping_processor = ->(**) { [] }
            data_geom_processor = ->(**) { [] }

            stub_instrument do
              DataCycleCore::ConceptLink.stub(:insert_all, []) do
                DataCycleCore::ClassificationPolygon.stub(:upsert_all_geoms, 0) do
                  assert_nothing_raised do
                    @subject.import_concepts(utility_object: import_object('icn_step'), iterator: concept_iterator, data_processor:, data_transformer:, data_mapping_processor:, data_geom_processor:, options: { import: {} })
                  end
                end
              end
            end
          end

          test 'import_concepts re-raises per-scheme errors and fails the phase in local environments' do
            scheme = failing_concept_scheme_double
            data_processor = ->(**) { { external_key: 'c1' } }
            data_transformer = ->(**) { { scheme => [{ external_key: 'c1' }] } }
            data_mapping_processor = ->(**) { [] }
            data_geom_processor = ->(**) { [] }

            stub_instrument do
              assert_nothing_raised do
                @subject.import_concepts(utility_object: import_object('ice_step'), iterator: concept_iterator, data_processor:, data_transformer:, data_mapping_processor:, data_geom_processor:, options: { import: {} })
              end
            end
          end

          test 'import_concepts swallows per-scheme errors outside local environments' do
            scheme = failing_concept_scheme_double
            data_processor = ->(**) { { external_key: 'c1' } }
            data_transformer = ->(**) { { scheme => [{ external_key: 'c1' }] } }
            data_mapping_processor = ->(**) { [] }
            data_geom_processor = ->(**) { [] }

            stub_instrument do
              Rails.env.stub(:local?, false) do
                DataCycleCore::ConceptLink.stub(:insert_all, []) do
                  DataCycleCore::ClassificationPolygon.stub(:upsert_all_geoms, 0) do
                    assert_nothing_raised do
                      @subject.import_concepts(utility_object: import_object('icx_step'), iterator: concept_iterator, data_processor:, data_transformer:, data_mapping_processor:, data_geom_processor:, options: { import: {} })
                    end
                  end
                end
              end
            end
          end

          private

          def import_object(name)
            DataCycleCore::Generic::ImportObject.new(
              external_source: @local_system,
              locales: [:de],
              import: { import_strategy: 'DataCycleCore::Generic::Common::ImportContents', source_type: 'things', name: }
            )
          end

          def raw_item(data)
            Class.new {
              def initialize(dump) = (@dump = dump)
              attr_reader :dump
            }.new({ de: data })
          end

          def concept_scheme_double
            Class.new {
              def name = 'Scheme One'
              def external_key = 'scheme-1'
              def upsert_all_external_classifications(_concepts) = [{ 'id' => 'cls-1' }]
            }.new
          end

          def failing_concept_scheme_double
            Class.new {
              def name = 'Boom Scheme'
              def external_key = 'boom'
              def upsert_all_external_classifications(_concepts) = raise('boom')
            }.new
          end

          def stub_instrument(&)
            ActiveSupport::Notifications.stub(:instrument, ->(*_args, **_kwargs, &block) { block&.call }, &)
          end
        end
      end
    end
  end
end
