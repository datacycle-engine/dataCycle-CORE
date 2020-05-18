# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      class Thing < DataCycleCore::V4::Base
        setup do
          @event = DataCycleCore::V4::DummyDataHelper.create_data('event')
          @thing_count = DataCycleCore::Thing.where(template: false, content_type: 'entity').count
        end

        test 'api/v4/things default' do
          params = {
            id: @event.id
          }
          post api_v4_thing_path(params)

          json_data = JSON.parse response.body
          json_validate = json_data.dup

          # validate context
          json_context = json_validate.delete('@context')
          assert_equal(2, json_context.size)
          assert_equal('http://schema.org', json_context.first)
          validator = DataCycleCore::V4::Validation::Context.context
          assert_equal({}, validator.call(json_context.second).errors.to_h)

          validator = DataCycleCore::V4::Validation::Thing.thing
          assert_equal({}, validator.call(json_validate).errors.to_h)
        end

        test 'api/v4/things default width fields: startDate, endDate' do
          params = {
            id: @event.id,
            fields: 'startDate,endDate,description'
          }
          post api_v4_thing_path(params)

          json_data = JSON.parse response.body
          json_validate = json_data.dup

          # validate context
          json_context = json_validate.delete('@context')
          assert_equal(2, json_context.size)
          assert_equal('http://schema.org', json_context.first)
          validator = DataCycleCore::V4::Validation::Context.context
          assert_equal({}, validator.call(json_context.second).errors.to_h)

          fields = Dry::Schema.JSON do
            required(:startDate).value(:date_time)
            required(:endDate).value(:date_time)
            optional(:description).value(:string)
          end

          validator = DataCycleCore::V4::Validation::Thing.thing(params: { fields: fields })
          assert_equal({}, validator.call(json_validate).errors.to_h)
        end

        # TODO: fix things
        test 'api/v4/things default width fields: image,location' do
          params = {
            id: @event.id,
            fields: 'location,image'
          }
          post api_v4_thing_path(params)

          json_data = JSON.parse response.body
          json_validate = json_data.dup

          # validate context
          json_context = json_validate.delete('@context')
          assert_equal(2, json_context.size)
          assert_equal('http://schema.org', json_context.first)
          validator = DataCycleCore::V4::Validation::Context.context
          assert_equal({}, validator.call(json_context.second).errors.to_h)

          fields = Dry::Schema.JSON do
            required(:image).value(:array, min_size?: 1).each do
              hash(DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER)
            end
            required(:location).value(:array, min_size?: 1).each do
              hash(DataCycleCore::V4::Validation::Thing::DEFAULT_HEADER)
            end
          end

          validator = DataCycleCore::V4::Validation::Thing.thing(params: { fields: fields })
          assert_equal({}, validator.call(json_validate).errors.to_h)
        end

        # params = {
        #               id: tree_id,
        #               classification_id: update_tag.id,
        #               fields: 'skos:prefLabel,dct:description,dct:modified,identifier'
        #             }
        #
      end
    end
  end
end
