# frozen_string_literal: true

module DataCycleCore
  module TestData
    # Provides a valid asset id for an `asset` property by creating a real, system-owned
    # asset from the core's bundled fixture files (the same files the test suite uploads),
    # falling back to an existing asset of that type. Results are cached per asset type so a
    # generation run attaches each fixture once. Returns nil when no asset can be provided.
    class AssetSource
      # asset_type => [fixture subdirectory, file] under the core's fixture files.
      FIXTURES = {
        'image' => ['images', 'test_rgb.jpeg'],
        'video' => ['videos', 'test.mp4'],
        'audio' => ['audio', 'test.mp3'],
        'pdf' => ['pdf', 'test.pdf'],
        'text_file' => ['text_file', 'test.pdf'],
        'data_cycle_file' => ['text_file', 'test.pdf']
      }.freeze
      # asset_type left blank in the schema defaults to an image.
      DEFAULT_TYPE = 'image'

      def initialize
        @cache = {}
      end

      # @return [String, nil] id of a usable asset of the given type, or nil if none could be provided.
      def id_for(asset_type)
        type = asset_type.presence || DEFAULT_TYPE
        return @cache[type] if @cache.key?(type)

        @cache[type] = create_from_fixture(type) || existing_id(type)
      end

      private

      def model(type)
        "DataCycleCore::#{type.camelize}".safe_constantize
      end

      def existing_id(type)
        model(type)&.first&.id
      rescue StandardError
        nil
      end

      def create_from_fixture(type)
        klass = model(type)
        subdir, filename = FIXTURES[type]
        return if klass.nil? || subdir.nil?

        path = fixtures_root.join(subdir, filename)
        return unless File.exist?(path)

        asset = klass.new(creator: nil)
        asset.file.attach(io: File.open(path), filename:)
        asset.id if asset.save
      rescue StandardError
        nil
      end

      def fixtures_root
        @fixtures_root ||= DataCycleCore::Engine.root.join('test', 'fixtures', 'files')
      end
    end
  end
end
