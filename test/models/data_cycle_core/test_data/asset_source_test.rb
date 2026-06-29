# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module TestData
    # Verifies the asset source creates real, system-owned assets from the core's bundled
    # fixture files (the same files the test suite uploads) and caches them per type.
    class AssetSourceTest < DataCycleCore::TestCases::ActiveSupportTestCase
      test 'creates a real, persisted, system-owned image asset with an attached file' do
        id = AssetSource.new.id_for('image')

        assert_not_nil id
        image = DataCycleCore::Image.find(id)

        assert_predicate image.file, :attached?
        assert_nil image.creator_id
      end

      test 'creates real assets for the video and audio types too' do
        source = AssetSource.new

        assert_predicate DataCycleCore::Video.find(source.id_for('video')).file, :attached?
        assert_predicate DataCycleCore::Audio.find(source.id_for('audio')).file, :attached?
      end

      test 'caches one asset per type across repeated calls' do
        source = AssetSource.new

        assert_equal source.id_for('image'), source.id_for('image')
      end

      test 'defaults a blank asset type to an image' do
        id = AssetSource.new.id_for(nil)

        assert_predicate DataCycleCore::Image.find(id).file, :attached?
      end
    end
  end
end
