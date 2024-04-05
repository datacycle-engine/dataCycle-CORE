# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class EmbeddedMultipleTemplatesTest < ActiveSupport::TestCase
        test 'insert multiple embedded of different types' do
          data_set = DataCycleCore::TestPreparations.create_content(
            template_name: 'Embedded-Multiple-Templates-Entity-1',
            data_hash: {
              embedded_creative_work: [{
                name: 'test 1',
                template_name: 'Embedded-Multiple-Templates-1'
              }, {
                name: 'test 1',
                template_name: 'Embedded-Multiple-Templates-2'
              }]
            }
          )

          assert_equal ['Embedded-Multiple-Templates-1', 'Embedded-Multiple-Templates-2'], data_set.embedded_creative_work.pluck(:template_name)
        end

        test 'insert multiple embedded of different types without template_names raises Error on validation' do
          assert_raise(DataCycleCore::Error::TemplateNotAllowedError) do
            DataCycleCore::TestPreparations.create_content(
              template_name: 'Embedded-Multiple-Templates-Entity-1',
              data_hash: {
                embedded_creative_work: [{
                  name: 'test 1'
                }, {
                  name: 'test 1'
                }]
              }
            )
          end
        end

        test 'insert multiple embedded of different types with wrong template_names raises Error on validation' do
          assert_raise(DataCycleCore::Error::TemplateNotAllowedError) do
            DataCycleCore::TestPreparations.create_content(
              template_name: 'Embedded-Multiple-Templates-Entity-1',
              data_hash: {
                embedded_creative_work: [{
                  name: 'test 1',
                  template_name: 'Embedded-Creative-Work-2'
                }, {
                  name: 'test 1',
                  template_name: 'Embedded-Creative-Work-2'
                }]
              }
            )
          end
        end
      end
    end
  end
end
