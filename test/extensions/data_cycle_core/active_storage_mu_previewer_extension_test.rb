# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ActiveStorageMuPreviewerExtensionTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def previewer_class
      Class.new do
        include DataCycleCore::ActiveStorageMuPreviewerExtension

        def self.mutool_path
          '/usr/bin/mutool'
        end

        def self.name
          'DataCycleCore::PdfPreviewer'
        end

        def draw(*args)
          args
        end
      end
    end

    test 'returns no options when the custom previewer feature is disabled' do
      previewer = previewer_class.new

      DataCycleCore::Feature::CustomAssetPreviewer.stub(:enabled?, false) do
        assert_equal [], previewer.send(:transformed_previewer_options)
      end
    end

    test 'returns no options when the previewer has no configured options' do
      previewer = previewer_class.new

      DataCycleCore::Feature::CustomAssetPreviewer.stub(:enabled?, true) do
        DataCycleCore::Feature::CustomAssetPreviewer.stub(:previewer_options, {}) do
          assert_equal [], previewer.send(:transformed_previewer_options)
        end
      end
    end

    test 'maps configured options to mutool flags' do
      previewer = previewer_class.new

      DataCycleCore::Feature::CustomAssetPreviewer.stub(:enabled?, true) do
        DataCycleCore::Feature::CustomAssetPreviewer.stub(:previewer_options, { resolution: 150 }) do
          assert_equal ['-r', '150'], previewer.send(:transformed_previewer_options)
        end
      end
    end

    test 'draws the first page passing the file path to mutool' do
      previewer = previewer_class.new
      file = Object.new
      file.define_singleton_method(:path) { '/tmp/document.pdf' }

      DataCycleCore::Feature::CustomAssetPreviewer.stub(:enabled?, false) do
        args = previewer.send(:draw_first_page_from, file)

        assert_includes args, '/tmp/document.pdf'
        assert_includes args, 'draw'
      end
    end
  end
end
