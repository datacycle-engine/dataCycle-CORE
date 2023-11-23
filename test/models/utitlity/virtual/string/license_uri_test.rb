# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Utility
    module Virtual
      module String
        class LicenseUriText < DataCycleCore::TestCases::ActiveSupportTestCase
          before(:all) do
            @cc_by_40_uri = 'https://creativecommons.org/licenses/by/4.0/'
            @licenses = DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: 'Lizenzen')
            @cc_by_40 = @licenses.create_classification_alias(
              'Open Data',
              'Creative Commons',
              { name: 'CC BY', uri: 'Test URI' },
              { name: 'CC BY 4.0', uri: @cc_by_40_uri }
            )

            image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
            image_data_hash['universal_classifications'] = [@cc_by_40.primary_classification.id]
            @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)
          end

          test 'license_uri with preloaded collected_classification_contents' do
            thing = DataCycleCore::Thing.where(id: @image.id).preload(collected_classification_contents: [:classification_tree_label, classification_alias: [:classification_alias_path]])

            assert_equal(@cc_by_40_uri, DataCycleCore::Utility::Virtual::String.license_uri(content: thing.first))
          end

          test 'license_uri without preloaded collected_classification_contents' do
            assert_equal(@cc_by_40_uri, DataCycleCore::Utility::Virtual::String.license_uri(content: @image))
          end
        end
      end
    end
  end
end
