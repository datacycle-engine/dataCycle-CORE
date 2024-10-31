# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationFilterTest < DataCycleCore::V4::Base
          # rubocop:disable Minitest/MultipleAssertions
          before(:all) do
            DataCycleCore::Thing.delete_all
            @tags = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            @tag_aliases = @tags.classification_aliases.to_h { |v| [v.internal_name, v.id] }
            @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count
            other_trees = DataCycleCore::ClassificationTreeLabel.where.not(name: 'Tags')
            now = Time.zone.now
            other_trees.update_all(created_at: now, updated_at: now, seen_at: now)
          end

          # TODO: add context test
          # add tests to combine created / modified

          test 'api/v4/concept_schemes parameter filter[:dct:created]' do
            orig_ts = @tags.created_at

            @tags.update_column(:created_at, 10.days.from_now)
            params = {
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      min: 5.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)

            params = {
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      min: 5.days.from_now.to_fs(:iso8601),
                      max: 12.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)

            @tags.update_column(:created_at, 10.days.ago)
            params = {
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      max: 5.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)

            @tags.update_column(:created_at, 10.days.from_now)
            params = {
              filter: {
                attribute: {
                  'dct:created': {
                    notIn: {
                      min: 5.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              },
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(@trees - 1)

            params = {
              filter: {
                attribute: {
                  'dct:created': {
                    notIn: {
                      min: 5.days.from_now.to_fs(:iso8601),
                      max: 12.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              },
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(@trees - 1)

            @tags.update_column(:created_at, 10.days.ago)
            params = {
              filter: {
                attribute: {
                  'dct:created': {
                    notIn: {
                      max: 5.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              },
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(@trees - 1)

            params = {
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      max: 5.days.ago.to_fs(:iso8601)
                    },
                    notIn: {
                      max: 15.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)

            @tags.update_column(:created_at, orig_ts)
          end

          test 'api/v4/concept_schemes parameter filter[:dct:modified]' do
            orig_ts = @tags.updated_at

            @tags.update_column(:updated_at, 10.days.from_now)
            params = {
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      min: 5.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)

            params = {
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      min: 5.days.from_now.to_fs(:iso8601),
                      max: 12.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)

            @tags.update_column(:updated_at, 10.days.ago)
            params = {
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      max: 5.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)

            @tags.update_column(:updated_at, 10.days.from_now)
            params = {
              filter: {
                attribute: {
                  'dct:modified': {
                    notIn: {
                      min: 5.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              },
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(@trees - 1)

            params = {
              filter: {
                attribute: {
                  'dct:modified': {
                    notIn: {
                      min: 5.days.from_now.to_fs(:iso8601),
                      max: 12.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              },
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(@trees - 1)

            @tags.update_column(:updated_at, 10.days.ago)
            params = {
              filter: {
                attribute: {
                  'dct:modified': {
                    notIn: {
                      max: 5.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              },
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(@trees - 1)

            params = {
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      max: 5.days.ago.to_fs(:iso8601)
                    },
                    notIn: {
                      max: 15.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)

            @tags.update_column(:updated_at, orig_ts)
          end

          test 'api/v4/concept_schemes parameter filter[:dct:deleted]' do
            params = {
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      min: 20.years.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(0)

            DataCycleCore::MasterData::ImportClassifications.import_all(classification_paths: [Rails.root.join('..', 'fixtures', 'data', 'classifications')])
            DataCycleCore::ClassificationTreeLabel.find_by(name: 'Test').destroy

            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)

            params = {
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      max: 20.years.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(1)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[:created_at]' do
            tree_id = @tags.id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags')
            now = Time.zone.now
            classifications.update_all(created_at: now, updated_at: now, seen_at: now)
            classifications_count = classifications.count
            classificaton_tag = classifications.with_name('Tag 3').first
            orig_ts = classificaton_tag.created_at

            classificaton_tag.update_column(:created_at, 10.days.from_now)
            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      min: 5.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(1)

            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      min: 5.days.from_now.to_fs(:iso8601),
                      max: 12.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(1)

            classificaton_tag.update_column(:created_at, 10.days.ago)
            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      max: 5.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(1)

            classificaton_tag.update_column(:created_at, 10.days.from_now)
            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:created': {
                    notIn: {
                      min: 5.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications_count - 1)

            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:created': {
                    notIn: {
                      min: 5.days.from_now.to_fs(:iso8601),
                      max: 12.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications_count - 1)

            classificaton_tag.update_column(:created_at, 10.days.ago)
            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:created': {
                    notIn: {
                      max: 5.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications_count - 1)

            params = {
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      max: 5.days.ago.to_fs(:iso8601)
                    },
                    notIn: {
                      max: 15.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(1)

            classificaton_tag.update_column(:created_at, orig_ts)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[:dct:modified]' do
            tree_id = @tags.id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags')
            classifications_count = classifications.count
            classificaton_tag = classifications.with_name('Tag 3').first
            orig_ts = classificaton_tag.updated_at

            classificaton_tag.update_column(:updated_at, 10.days.from_now)
            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      min: 5.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(1)

            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      min: 5.days.from_now.to_fs(:iso8601),
                      max: 12.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(1)

            classificaton_tag.update_column(:updated_at, 10.days.ago)
            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      max: 5.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(1)

            classificaton_tag.update_column(:updated_at, 10.days.from_now)
            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:modified': {
                    notIn: {
                      min: 5.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications_count - 1)

            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:modified': {
                    notIn: {
                      min: 5.days.from_now.to_fs(:iso8601),
                      max: 12.days.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications_count - 1)

            classificaton_tag.update_column(:updated_at, 10.days.ago)
            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:modified': {
                    notIn: {
                      max: 5.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications_count - 1)

            params = {
              filter: {
                attribute: {
                  'dct:modified': {
                    in: {
                      max: 5.days.ago.to_fs(:iso8601)
                    },
                    notIn: {
                      max: 15.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(1)

            classificaton_tag.update_column(:updated_at, orig_ts)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[:dct:deleted]' do
            DataCycleCore::MasterData::ImportClassifications.import_all(classification_paths: [Rails.root.join('..', 'fixtures', 'data', 'classifications')])
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Test').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Test').count
            params = {
              id: tree_id,
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      min: 20.years.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }

            get classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(0)

            DataCycleCore::ClassificationAlias.for_tree('Test').destroy_all
            get classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)

            params = {
              filter: {
                attribute: {
                  'dct:deleted': {
                    in: {
                      max: 20.years.from_now.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            get classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[:q] filter[:search]' do
            tree_id = @tags.id

            params = {
              id: tree_id,
              filter: {
                q: 'Tag'
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(5)

            params = {
              id: tree_id,
              filter: {
                q: 'Nested'
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(2)

            params = {
              id: tree_id,
              filter: {
                search: 'Tag'
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(5)

            params = {
              id: tree_id,
              filter: {
                search: 'Nested'
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(2)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:broader][in] without children' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:broader': { in: @tag_aliases.values_at('Tag 1') } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(0)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:broader][in] with children' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:broader': { in: @tag_aliases.values_at('Tag 3') } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(2)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:broader][in] root' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:broader': { in: ['null'] } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(3)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:broader][in] with children and root' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:broader': { in: @tag_aliases.values_at('Tag 3') + ['null'] } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(5)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:broader][notIn] without children' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:broader': { notIn: @tag_aliases.values_at('Tag 1') } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(5)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:broader][notIn] with children' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:broader': { notIn: @tag_aliases.values_at('Tag 3') } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(3)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:broader][notIn] root' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:broader': { notIn: ['null'] } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(2)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:broader][notIn] with children and root' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:broader': { notIn: @tag_aliases.values_at('Tag 3') + ['null'] } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(0)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:ancestors][in] without children' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:ancestors': { in: @tag_aliases.values_at('Tag 1') } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(0)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:ancestors][in] with children' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:ancestors': { in: @tag_aliases.values_at('Tag 3') } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(2)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:ancestors][notIn] without children' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:ancestors': { notIn: @tag_aliases.values_at('Tag 1') } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(5)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[attribute][skos:ancestors][notIn] with children' do
            tree_id = @tags.id
            params = { id: tree_id, filter: { attribute: { 'skos:ancestors': { notIn: @tag_aliases.values_at('Tag 3') } } } }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(3)
          end

          # rubocop:enable Minitest/MultipleAssertions
        end
      end
    end
  end
end
