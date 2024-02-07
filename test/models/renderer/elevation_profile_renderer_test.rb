# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ElevationProfileRendererTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Tour', data_hash: { name: 'Test Tour', line: MasterData::DataConverter.string_to_geographic('MULTILINESTRING Z ((9.802584 47.150712 500, 9.802617 47.15066 520, 9.802537 47.150632 480))') }, prevent_history: true)
      @content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel' }, prevent_history: true)
    end

    test 'elevation_profile_renderer raises exception for missing thing' do
      assert_raises(ActiveRecord::RecordNotFound) do
        DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content: nil)
      end
    end

    test 'elevation_profile_renderer raises exception for thing without geo attributes' do
      assert_raises(DataCycleCore::ApiRenderer::Error::RendererError) do
        renderer = DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content: @content2)
        renderer.render
      end
    end

    test 'elevation_profile_renderer raises exception for tour without geo data' do
      @content.set_data_hash(data_hash: { line: nil })

      assert_raises(DataCycleCore::ApiRenderer::Error::RendererError) do
        renderer = DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content: @content)
        renderer.render
      end
    end

    test 'elevation_profile_renderer raises exception for tour without elevation data' do
      @content.set_data_hash(data_hash: { line: MasterData::DataConverter.string_to_geographic('MULTILINESTRING Z ((9.802584 47.150712 0, 9.802617 47.15066 0, 9.802537 47.150632 0))') })

      assert_raises(DataCycleCore::ApiRenderer::Error::RendererError) do
        renderer = DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content: @content)
        renderer.render
      end
    end

    test 'elevation_profile_renderer returns elevation_profile as array of objects' do
      renderer = DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content: @content)
      data = JSON.parse(renderer.render)

      assert_equal(0.0, data.dig('data', 0, 'x'))
      assert_equal(500, data.dig('data', 0, 'y'))
      assert_equal(520, data.dig('data', 1, 'y'))
      assert_equal(480, data.dig('data', 2, 'y'))
      assert_equal([9.802584, 47.150712], data.dig('data', 0, 'coordinates'))
      assert_equal([9.802617, 47.15066], data.dig('data', 1, 'coordinates'))
      assert_equal([9.802537, 47.150632], data.dig('data', 2, 'coordinates'))
    end

    test 'elevation_profile_renderer returns elevation_profile as array of arrays' do
      renderer = DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content: @content, data_format: 'array')
      data = JSON.parse(renderer.render)

      assert_equal(0.0, data.dig('data', 0, 0))
      assert_equal(500, data.dig('data', 0, 1))
      assert_equal(520, data.dig('data', 1, 1))
      assert_equal(480, data.dig('data', 2, 1))
      assert_equal([9.802584, 47.150712], data.dig('data', 0, 2))
      assert_equal([9.802617, 47.15066], data.dig('data', 1, 2))
      assert_equal([9.802537, 47.150632], data.dig('data', 2, 2))
    end
  end
end
