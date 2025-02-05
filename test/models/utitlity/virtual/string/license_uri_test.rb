# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Utility
    module Virtual
      module String
        class LicenseUriText < DataCycleCore::TestCases::ActiveSupportTestCase
          before(:all) do
            @cc_by40_uri = 'https://creativecommons.org/licenses/by/4.0/'
            @licenses = DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: 'Lizenzen')
            @cc_by40 = @licenses.create_classification_alias(
              'Open Data',
              'Creative Commons',
              { name: 'CC BY', uri: 'Test URI' },
              { name: 'CC BY 4.0', uri: @cc_by40_uri }
            )

            image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
            image_data_hash['universal_classifications'] = [@cc_by40.primary_classification.id]
            @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)
          end

          test 'license_uri with preloaded collected_classification_contents' do
            thing = DataCycleCore::Thing.where(id: @image.id).preload(collected_classification_contents: [:classification_tree_label, {classification_alias: [:classification_alias_path]}]).first

            assert_equal(@cc_by40_uri, DataCycleCore::Utility::Virtual::String.license_uri(content: thing))
          end

          test 'license_uri without preloaded collected_classification_contents' do
            assert_equal(@cc_by40_uri, DataCycleCore::Utility::Virtual::String.license_uri(content: @image))
          end

          test 'license_uri with empty preloaded collected_classification_contents' do
            new_thing = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'TestBildLicenseUriWithtoutClassifications', additional_information: [{ name: 'TestAddInfo' }] })
            thing = new_thing.additional_information.preload(collected_classification_contents: [:classification_tree_label, {classification_alias: [:classification_alias_path]}]).first

            assert_nil(DataCycleCore::Utility::Virtual::String.license_uri(content: thing))
          end
        end
      end
    end
  end
end
