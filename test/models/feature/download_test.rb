# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DownloadTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include ActiveJob::TestHelper

    before(:all) do
      image_file = upload_image('test_rgb.jpeg')
      image_data_hash = {
        'name' => 'image_headline',
        'asset' => image_file.id
      }
      @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash, user: @current_user)
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Article Test' })
      @poi = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'POI Test' })
      @stored_filter = DataCycleCore::StoredFilter.create(
        name: 'TestFilter',
        user_id: User.find_by(email: 'tester@datacycle.at'),
        language: ['de'],
        parameters: [],
        api: true
      )
      @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      @serialize_config = DataCycleCore.features[:serialize].deep_dup
      @download_config = DataCycleCore.features[:download].deep_dup
    end

    # after(:all) do
    # end

    # only gps download must be enabled
    test 'validate default configuration' do
      assert_equal(['gpx', 'license'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@content).blank?)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@image).blank?)

      assert_not(DataCycleCore::Feature::Download.allowed?(@content))
      assert_not(DataCycleCore::Feature::Download.allowed?(@image))

      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))

      assert(DataCycleCore::Feature::Download.allowed?(@poi))
      assert_equal(['gpx'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@poi).keys.sort)
    end

    # only gps download must be enabled
    test 'disable content downloader' do
      assert_equal(['gpx', 'license'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@content).blank?)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@image).blank?)

      DataCycleCore.features[:download][:downloader][:content][:enabled] = false

      assert_not(DataCycleCore::Feature::Download.allowed?(@content))
      assert_not(DataCycleCore::Feature::Download.allowed?(@image))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@poi))
    end

    # only gps download must be enabled
    test 'disable content downloader for things' do
      assert_equal(['gpx', 'license'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@content).blank?)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@image).blank?)

      DataCycleCore.features[:download][:downloader][:content][:thing][:enabled] = false

      assert_not(DataCycleCore::Feature::Download.allowed?(@content))
      assert_not(DataCycleCore::Feature::Download.allowed?(@image))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@poi))
    end

    test 'enable asset, json and xml serializers for content (things) downloader' do
      DataCycleCore.features[:serialize][:serializers][:asset] = true
      DataCycleCore.features[:serialize][:serializers][:json] = true
      DataCycleCore.features[:serialize][:serializers][:xml] = true

      assert_equal(['asset', 'gpx', 'json', 'license', 'xml'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@content).present?)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@image).present?)

      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:asset] = true
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:json] = true
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:xml] = true

      assert(DataCycleCore::Feature::Download.allowed?(@content))
      assert(DataCycleCore::Feature::Download.allowed?(@image))
      assert(DataCycleCore::Feature::Download.allowed?(@poi))
      assert_equal(['json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@content).keys.sort)
      assert_equal(['asset', 'json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@image).keys.sort)
      assert_equal(['gpx', 'json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@poi).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
    end

    test 'enable json and xml serializers for content (watch_list) downloader' do
      DataCycleCore.features[:serialize][:serializers][:json] = true
      DataCycleCore.features[:serialize][:serializers][:xml] = true

      assert_equal(['gpx', 'json', 'license', 'xml'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@content).present?)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@image).present?)

      DataCycleCore.features[:download][:downloader][:content][:watch_list][:enabled] = true
      DataCycleCore.features[:download][:downloader][:content][:watch_list][:serializers][:json] = true
      DataCycleCore.features[:download][:downloader][:content][:watch_list][:serializers][:xml] = true

      assert_not(DataCycleCore::Feature::Download.allowed?(@content))
      assert_not(DataCycleCore::Feature::Download.allowed?(@image))
      assert(DataCycleCore::Feature::Download.allowed?(@poi))
      assert_equal(['gpx'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@poi).keys.sort)

      assert(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_equal(['json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@watch_list).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
    end

    test 'enable json and xml serializers for content (stored_filter) downloader' do
      DataCycleCore.features[:serialize][:serializers][:json] = true
      DataCycleCore.features[:serialize][:serializers][:xml] = true

      assert_equal(['gpx', 'json', 'license', 'xml'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@content).present?)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@image).present?)

      DataCycleCore.features[:download][:downloader][:content][:stored_filter][:enabled] = true
      DataCycleCore.features[:download][:downloader][:content][:stored_filter][:serializers][:json] = true
      DataCycleCore.features[:download][:downloader][:content][:stored_filter][:serializers][:xml] = true

      assert_not(DataCycleCore::Feature::Download.allowed?(@content))
      assert_not(DataCycleCore::Feature::Download.allowed?(@image))
      assert(DataCycleCore::Feature::Download.allowed?(@poi))
      assert_equal(['gpx'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@poi).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_equal(['json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@stored_filter).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
    end

    test 'enable asset, gpx, json and xml serializers for archive.zip (content) downloader' do
      DataCycleCore.features[:serialize][:serializers][:asset] = true
      DataCycleCore.features[:serialize][:serializers][:gpx] = true
      DataCycleCore.features[:serialize][:serializers][:json] = true
      DataCycleCore.features[:serialize][:serializers][:xml] = true

      assert_equal(['asset', 'gpx', 'json', 'license', 'xml'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@content).present?)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@image).present?)

      DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = false
      DataCycleCore.features[:download][:downloader][:archive][:zip][:thing][:enabled] = true
      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :zip]))

      DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:zip][:thing][:enabled] = false
      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :zip]))

      # enable archive zip thing downloader
      DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:zip][:thing][:enabled] = true
      assert(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :zip]))
      # only gpx is enabled in downloader.content.thing.serializers
      assert_equal(['gpx'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@content, [:archive, :zip]).keys.sort)
      assert_not(DataCycleCore::Feature::Download.allowed?(@content))
      assert_not(DataCycleCore::Feature::Download.allowed?(@image))
      assert(DataCycleCore::Feature::Download.allowed?(@poi))

      # enable asset, json and xml serializer for downloader.content.thing
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:asset] = true
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:json] = true
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:xml] = true
      assert_equal(['asset', 'gpx', 'json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@content, [:archive, :zip]).keys.sort)
      assert(DataCycleCore::Feature::Download.allowed?(@content))
      assert(DataCycleCore::Feature::Download.allowed?(@image))
      assert(DataCycleCore::Feature::Download.allowed?(@poi))

      # overrule enabled serializers
      DataCycleCore.features[:download][:downloader][:archive][:zip][:thing][:serializers] = { asset: false, gpx: false }
      assert_equal(['json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@content, [:archive, :zip]).keys.sort)

      # check mandatory serializers
      assert_equal([], DataCycleCore::Feature::Download.mandatory_serializers_for_download(@content, [:archive, :zip]).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
    end

    test 'enable asset, gpx, json and xml serializers for archive.zip (watch_list) downloader' do
      DataCycleCore.features[:serialize][:serializers][:asset] = true
      DataCycleCore.features[:serialize][:serializers][:gpx] = true
      DataCycleCore.features[:serialize][:serializers][:json] = true
      DataCycleCore.features[:serialize][:serializers][:xml] = true

      assert_equal(['asset', 'gpx', 'json', 'license', 'xml'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@content).present?)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@image).present?)

      DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = false
      DataCycleCore.features[:download][:downloader][:archive][:zip][:watch_list][:enabled] = true
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))

      DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:zip][:watch_list][:enabled] = false
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))

      # enable archive zip thing downloader
      DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:zip][:watch_list][:enabled] = true
      assert(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
      # only gpx is enabled in downloader.content.thing.serializers
      assert_equal(['gpx'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@watch_list, [:archive, :zip]).keys.sort)
      assert_not(DataCycleCore::Feature::Download.allowed?(@content))
      assert_not(DataCycleCore::Feature::Download.allowed?(@image))
      assert(DataCycleCore::Feature::Download.allowed?(@poi))

      # enable asset, json and xml serializer for downloader.content.thing
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:asset] = true
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:json] = true
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:xml] = true
      assert_equal(['asset', 'gpx', 'json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@watch_list, [:archive, :zip]).keys.sort)
      assert(DataCycleCore::Feature::Download.allowed?(@content))
      assert(DataCycleCore::Feature::Download.allowed?(@image))
      assert(DataCycleCore::Feature::Download.allowed?(@poi))

      # overrule enabled serializers
      DataCycleCore.features[:download][:downloader][:archive][:zip][:watch_list][:serializers] = { asset: false, gpx: false }
      assert_equal(['json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@watch_list, [:archive, :zip]).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
    end

    test 'enable asset, gpx, json and xml serializers for archive.zip (stored_filter) downloader' do
      DataCycleCore.features[:serialize][:serializers][:asset] = true
      DataCycleCore.features[:serialize][:serializers][:gpx] = true
      DataCycleCore.features[:serialize][:serializers][:json] = true
      DataCycleCore.features[:serialize][:serializers][:xml] = true

      assert_equal(['asset', 'gpx', 'json', 'license', 'xml'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@content).present?)
      assert(DataCycleCore::Feature::Serialize.available_serializers(@image).present?)

      DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = false
      DataCycleCore.features[:download][:downloader][:archive][:zip][:stored_filter][:enabled] = true
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))

      DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:zip][:stored_filter][:enabled] = false
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))

      # enable archive zip thing downloader
      DataCycleCore.features[:download][:downloader][:archive][:zip][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:zip][:stored_filter][:enabled] = true
      assert(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      # only gpx is enabled in downloader.content.thing.serializers
      assert_equal(['gpx'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@stored_filter, [:archive, :zip]).keys.sort)
      assert_not(DataCycleCore::Feature::Download.allowed?(@content))
      assert_not(DataCycleCore::Feature::Download.allowed?(@image))
      assert(DataCycleCore::Feature::Download.allowed?(@poi))

      # enable asset, json and xml serializer for downloader.content.thing
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:asset] = true
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:json] = true
      DataCycleCore.features[:download][:downloader][:content][:thing][:serializers][:xml] = true
      assert_equal(['asset', 'gpx', 'json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@stored_filter, [:archive, :zip]).keys.sort)
      assert(DataCycleCore::Feature::Download.allowed?(@content))
      assert(DataCycleCore::Feature::Download.allowed?(@image))
      assert(DataCycleCore::Feature::Download.allowed?(@poi))

      # overrule enabled serializers
      DataCycleCore.features[:download][:downloader][:archive][:zip][:stored_filter][:serializers] = { asset: false, gpx: false }
      assert_equal(['json', 'xml'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@stored_filter, [:archive, :zip]).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
    end

    test 'enable archive.indesign (content) downloader' do
      DataCycleCore.features[:serialize][:serializers][:indesign] = true
      DataCycleCore.features[:serialize][:serializers][:asset] = true
      assert_equal(['asset', 'gpx', 'indesign', 'license'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)

      DataCycleCore.features[:download][:downloader][:archive][:indesign][:enabled] = false
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:thing][:enabled] = true
      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :indesign]))

      DataCycleCore.features[:download][:downloader][:archive][:indesign][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:thing][:enabled] = false
      assert_not(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :indesign]))

      # enable archive zip thing downloader
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:thing][:enabled] = true
      assert(DataCycleCore::Feature::Download.allowed?(@content, [:archive, :indesign]))

      # make sure indesign is enabled
      assert_equal(['gpx', 'indesign'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@content, [:archive, :indesign]).keys.sort)

      # overrule enabled serializers
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:thing][:serializers][:gpx] = false
      assert_equal(['indesign'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@content, [:archive, :indesign]).keys.sort)

      # check mandatory serializers
      assert_equal(['asset'], DataCycleCore::Feature::Download.mandatory_serializers_for_download(@content, [:archive, :indesign]).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
    end

    test 'enable archive.indesign (watch_list) downloader' do
      DataCycleCore.features[:serialize][:serializers][:indesign] = true
      DataCycleCore.features[:serialize][:serializers][:asset] = true
      assert_equal(['asset', 'gpx', 'indesign', 'license'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)

      DataCycleCore.features[:download][:downloader][:archive][:indesign][:enabled] = false
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:watch_list][:enabled] = true
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :indesign]))

      DataCycleCore.features[:download][:downloader][:archive][:indesign][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:watch_list][:enabled] = false
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :indesign]))

      # enable archive zip thing downloader
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:watch_list][:enabled] = true
      assert(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :indesign]))

      # make sure indesign is enabled
      assert_equal(['gpx', 'indesign'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@watch_list, [:archive, :indesign]).keys.sort)

      # overrule enabled serializers
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:watch_list][:serializers][:gpx] = false
      assert_equal(['indesign'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@watch_list, [:archive, :indesign]).keys.sort)

      # check mandatory serializers
      assert_equal(['asset'], DataCycleCore::Feature::Download.mandatory_serializers_for_download(@watch_list, [:archive, :indesign]).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
    end

    test 'enable archive.indesign (stored_filter) downloader' do
      DataCycleCore.features[:serialize][:serializers][:indesign] = true
      DataCycleCore.features[:serialize][:serializers][:asset] = true
      assert_equal(['asset', 'gpx', 'indesign', 'license'], DataCycleCore::Feature::Serialize.available_serializers.keys.sort)

      DataCycleCore.features[:download][:downloader][:archive][:indesign][:enabled] = false
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:stored_filter][:enabled] = true
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :indesign]))

      DataCycleCore.features[:download][:downloader][:archive][:indesign][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:stored_filter][:enabled] = false
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :indesign]))

      # enable archive zip thing downloader
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:enabled] = true
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:stored_filter][:enabled] = true
      assert(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :indesign]))

      # make sure indesign is enabled
      assert_equal(['gpx', 'indesign'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@stored_filter, [:archive, :indesign]).keys.sort)

      # overrule enabled serializers
      DataCycleCore.features[:download][:downloader][:archive][:indesign][:stored_filter][:serializers][:gpx] = false
      assert_equal(['indesign'], DataCycleCore::Feature::Download.enabled_serializers_for_download(@stored_filter, [:archive, :indesign]).keys.sort)

      # check mandatory serializers
      assert_equal(['asset'], DataCycleCore::Feature::Download.mandatory_serializers_for_download(@stored_filter, [:archive, :indesign]).keys.sort)

      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list))
      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter))

      assert_not(DataCycleCore::Feature::Download.allowed?(@stored_filter, [:archive, :zip]))
      assert_not(DataCycleCore::Feature::Download.allowed?(@watch_list, [:archive, :zip]))
    end

    def teardown
      DataCycleCore.features[:serialize][:serializers] = @serialize_config[:serializers].deep_dup
      DataCycleCore.features[:download][:downloader] = @download_config[:downloader].deep_dup
      DataCycleCore::Feature::Serialize.reload
      DataCycleCore::Feature::Download.reload
    end
  end
end
