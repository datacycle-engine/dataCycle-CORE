# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class OverlayTest < ActiveSupport::TestCase
    setup do
      @poi = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Test POI 1' })
      @poi_overlay = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'Test POI 2' })
      @poi_overlay.set_data_hash(data_hash: { name: 'Test POI 2', overlay: [{ name: 'Test Overlay' }] })
      # Rails.backtrace_cleaner.remove_silencers!
      # content = DataCycleCore::Thing.new
      # image = DataCycleCore::Thing.find_by(template_name: 'POI')
      # content.schema = image.schema
      # content.template_name = image.template_name
      # content.save!
      # content.name = 'test'
      # content.set_data_hash(data_hash: { name: 'Test POI 1', overlay: [{ name: 'Test Overlay' }] })
    end

    test 'test overlay of simple attribute, no overlay present' do
      assert_equal('Test POI 1', @poi.name)
      assert_equal('Test POI 1', @poi.name_overlay)
    end

    test 'test with_overlay' do
      assert_equal('Test POI 2', @poi_overlay.name)
      assert_equal('Test Overlay', @poi_overlay.name_overlay)
    end
  end
end
