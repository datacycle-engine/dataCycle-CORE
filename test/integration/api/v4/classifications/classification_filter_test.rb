# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'v4/validation/concept'
require 'v4/helpers/api_helper'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationFilterTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers
          include DataCycleCore::V4::ApiHelper

          setup do
            DataCycleCore::Thing.where(template: false).delete_all
            @routes = Engine.routes
            @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'api/v4/concept_schemes parameter filter[:createdAt]' do
            tree_tags = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            orig_ts = tree_tags.created_at

            tree_tags.update_column(:created_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              filter: {
                createdAt: {
                  in: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)

            params = {
              filter: {
                createdAt: {
                  in: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601),
                    max: (Time.zone.now + 12.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)

            tree_tags.update_column(:created_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              filter: {
                createdAt: {
                  in: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)

            tree_tags.update_column(:created_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              filter: {
                createdAt: {
                  notIn: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees - 1)

            params = {
              filter: {
                createdAt: {
                  notIn: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601),
                    max: (Time.zone.now + 12.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees - 1)

            tree_tags.update_column(:created_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              filter: {
                createdAt: {
                  notIn: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees - 1)

            params = {
              filter: {
                createdAt: {
                  in: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  },
                  notIn: {
                    max: (Time.zone.now - 15.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)

            tree_tags.update_column(:created_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end
          test 'api/v4/concept_schemes parameter filter[:modifiedAt]' do
            tree_tags = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            orig_ts = tree_tags.updated_at

            tree_tags.update_column(:updated_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              filter: {
                modifiedAt: {
                  in: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)

            params = {
              filter: {
                modifiedAt: {
                  in: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601),
                    max: (Time.zone.now + 12.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)

            tree_tags.update_column(:updated_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              filter: {
                modifiedAt: {
                  in: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)

            tree_tags.update_column(:updated_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              filter: {
                modifiedAt: {
                  notIn: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees - 1)

            params = {
              filter: {
                modifiedAt: {
                  notIn: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601),
                    max: (Time.zone.now + 12.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees - 1)

            tree_tags.update_column(:updated_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              filter: {
                modifiedAt: {
                  notIn: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees - 1)

            params = {
              filter: {
                modifiedAt: {
                  in: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  },
                  notIn: {
                    max: (Time.zone.now - 15.days).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)

            tree_tags.update_column(:updated_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end

          test 'api/v4/concept_schemes parameter filter[:deletedAt]' do
            params = {
              filter: {
                deletedAt: {
                  in: {
                    min: (Time.zone.now - 20.years).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(0)

            DataCycleCore::MasterData::ImportClassifications.import_all(classification_paths: [Rails.root.join('..', 'dummy_data', 'classifications')])
            DataCycleCore::ClassificationTreeLabel.find_by(name: 'Test').destroy

            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)

            params = {
              filter: {
                deletedAt: {
                  in: {
                    max: (Time.zone.now + 20.years).to_s(:iso8601)
                  }
                }
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(1)
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[:created_since]' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags')
            classifications_count = classifications.count
            classificaton_tag = classifications.with_name('Tag 3').first
            orig_ts = classificaton_tag.created_at

            classificaton_tag.update_column(:created_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              id: tree_id,
              filter: {
                createdAt: {
                  in: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(1)

            params = {
              id: tree_id,
              filter: {
                createdAt: {
                  in: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601),
                    max: (Time.zone.now + 12.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(1)

            classificaton_tag.update_column(:created_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              id: tree_id,
              filter: {
                createdAt: {
                  in: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(1)

            classificaton_tag.update_column(:created_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              id: tree_id,
              filter: {
                createdAt: {
                  notIn: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count - 1)

            params = {
              id: tree_id,
              filter: {
                createdAt: {
                  notIn: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601),
                    max: (Time.zone.now + 12.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count - 1)

            classificaton_tag.update_column(:created_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              id: tree_id,
              filter: {
                createdAt: {
                  notIn: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count - 1)

            params = {
              filter: {
                createdAt: {
                  in: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  },
                  notIn: {
                    max: (Time.zone.now - 15.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(1)

            classificaton_tag.update_column(:created_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[:modified_since]' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags')
            classifications_count = classifications.count
            classificaton_tag = classifications.with_name('Tag 3').first
            orig_ts = classificaton_tag.updated_at

            classificaton_tag.update_column(:updated_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              id: tree_id,
              filter: {
                modifiedAt: {
                  in: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(1)

            params = {
              id: tree_id,
              filter: {
                modifiedAt: {
                  in: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601),
                    max: (Time.zone.now + 12.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(1)

            classificaton_tag.update_column(:updated_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              id: tree_id,
              filter: {
                modifiedAt: {
                  in: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(1)

            classificaton_tag.update_column(:updated_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              id: tree_id,
              filter: {
                modifiedAt: {
                  notIn: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count - 1)

            params = {
              id: tree_id,
              filter: {
                modifiedAt: {
                  notIn: {
                    min: (Time.zone.now + 5.days).to_s(:iso8601),
                    max: (Time.zone.now + 12.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count - 1)

            classificaton_tag.update_column(:updated_at, (Time.zone.now - 10.days)) # rubocop:disable Rails/SkipsModelValidations
            params = {
              id: tree_id,
              filter: {
                modifiedAt: {
                  notIn: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count - 1)

            params = {
              filter: {
                modifiedAt: {
                  in: {
                    max: (Time.zone.now - 5.days).to_s(:iso8601)
                  },
                  notIn: {
                    max: (Time.zone.now - 15.days).to_s(:iso8601)
                  }
                }
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(1)

            classificaton_tag.update_column(:updated_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end

          test 'api/v4/concept_schemes/id/concepts parameter filter[:deletedAt]' do
            DataCycleCore::MasterData::ImportClassifications.import_all(classification_paths: [Rails.root.join('..', 'dummy_data', 'classifications')])
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Test').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Test').count
            params = {
              id: tree_id,
              filter: {
                deletedAt: {
                  in: {
                    min: (Time.zone.now - 20.years).to_s(:iso8601)
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
                deletedAt: {
                  in: {
                    max: (Time.zone.now + 20.years).to_s(:iso8601)
                  }
                }
              }
            }
            get classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications)
          end
        end
      end
    end
  end
end