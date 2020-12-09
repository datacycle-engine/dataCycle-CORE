# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class AdvancedNumericTest < DataCycleCore::V4::Base
          # setup description
          # 2 images
          before(:all) do
            binding.pry
            image_a = DataCycleCore::V4::DummyDataHelper.create_data('image')
            image_a.set_data_hash(data_hash: { width: 100, height: 100 })

            image_b = DataCycleCore::V4::DummyDataHelper.create_data('image')
            image_b.set_data_hash(data_hash: { width: 50, height: 50 })

            # image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'TestBildB', author: [@organization.id] })
          end

          test 'api/v4/things with filter[attribute][{attributeName}][in][min]' do
            binding.pry
            post_params = {}
            post api_v4_things_path(post_params)
            assert_api_count_result(2)

            # withSubtree CC BY-SA 4.0 (2)
            post_params = {
              filter: {
                attribute: {
                  width: {
                    in: {
                      min: '150'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(post_params)
            assert_api_count_result(1)
          end

          # test 'api/v4/things with filter[classifications][notIn]' do

          # end

          # test 'api/v4/things with filter[dc:classification][in]' do

          # end

          # test 'api/v4/things with filter[dc:classification][notIn]' do

          # end
        end
      end
    end
  end
end
