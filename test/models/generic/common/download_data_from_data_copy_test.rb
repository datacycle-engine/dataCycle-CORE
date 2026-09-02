# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # [#50666] DownloadDataFromData without a `data_path` copies a whole dump.<locale> from one collection
  # into another, which used to carry the source's dc_step_priority into the target. The cap on
  # `priority:` rests on the target coming out *unclaimed*, and the freeze it repairs is live: imx has
  # 35 such steps across 4 installations, all reading the prioritised `places`.
  class DownloadDataFromDataCopyTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::DownloadDataFromData
    KEY = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::STEP_PRIORITY_KEY

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.create!(
        name: 'Download Data From Data Copy Test System',
        identifier: 'download-data-from-data-copy-test-system',
        config: {
          'download_config' => {
            'places' => { 'source_type' => 'dfd_places', 'priority' => 0 },
            'copy pois' => { 'source_type' => 'dfd_pois', 'read_type' => 'dfd_places' }
          }
        }
      )
    end

    after(:all) do
      DataCycleCore::MongoHelper.drop_mongo_db('download-data-from-data-copy-test-system')
    end

    def download_object(source_type)
      DataCycleCore::Generic::DownloadObject.new(
        external_source: @external_source,
        locales: [:de],
        download: { source_type:, name: 'copy pois', download_strategy: SUBJECT.to_s }
      )
    end

    # `label` rather than `name`, which the strategy fills from data_name_path (defaulting to the id)
    def seed_place(label)
      object = download_object('dfd_places')
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          mongo_item.find_or_initialize_by(external_id: 'pl-1')
            .tap { |item| item.dump = { 'de' => { 'id' => 'pl-1', 'label' => label, KEY => 0 } } }
            .save!
        end
      end
    end

    def copy_places_to_pois
      SUBJECT.download_content(
        utility_object: download_object('dfd_pois'),
        options: { locales: [:de], download: { name: 'copy pois', read_type: 'dfd_places' } }
      )
    end

    def poi_dump
      object = download_object('dfd_pois')
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          mongo_item.where(external_id: 'pl-1').first&.dump&.dig('de')
        end
      end
    end

    test 'the target of a whole-dump copy comes out unclaimed and stays writable' do
      seed_place('Place 1')
      copy_places_to_pois

      assert_equal 'Place 1', poi_dump['label']
      assert_not poi_dump.key?(KEY), "the copy inherited the source collection's claim"

      # the freeze in full: with the claim of 0 carried over, this unprioritised step loses against
      # what it wrote itself from the second run on (5 <= 0 is false)
      seed_place('Place 1 renamed')
      copy_places_to_pois

      assert_equal 'Place 1 renamed', poi_dump['label']
    end

    test 'a copy step configuring its own priority still claims the target' do
      seed_place('Place 2')

      SUBJECT.download_content(
        utility_object: download_object('dfd_pois_claimed'),
        options: { locales: [:de], download: { name: 'copy pois', read_type: 'dfd_places', priority: 2 } }
      )

      object = download_object('dfd_pois_claimed')
      dump = object.with_mongodb do
        object.source_object.with(object.source_type) { |mongo_item| mongo_item.where(external_id: 'pl-1').first&.dump&.dig('de') }
      end

      assert_equal 2, dump[KEY], 'props_from_config is the only writer, but it is still a writer'
    end
  end
end
