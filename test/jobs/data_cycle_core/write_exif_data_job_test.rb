# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WriteExifDataJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    UUID = '00000000-0000-0000-0000-000000000000'

    def named(value)
      obj = Object.new
      obj.define_singleton_method(:name) { value }
      obj
    end

    def asset_double(path: '/tmp/asset.jpg')
      service = Object.new
      service.define_singleton_method(:path_for) { |_key| path }
      file = Object.new
      file.define_singleton_method(:service) { service }
      file.define_singleton_method(:key) { 'key' }
      asset = Object.new
      asset.define_singleton_method(:file) { file }
      asset
    end

    def exif_double(changed: true)
      store = {}
      exif = Object.new
      exif.define_singleton_method(:[]=) { |key, value| store[key] = value }
      exif.define_singleton_method(:[]) { |key| store[key] }
      exif.define_singleton_method(:changed?) { changed }
      exif.define_singleton_method(:save) { true }
      exif.define_singleton_method(:store) { store }
      exif
    end

    def thing_double(asset:, variant: nil)
      authors = [named('Jane')]
      categories = [named('News')]
      tags = [named('Travel')]
      thing = Object.new
      thing.define_singleton_method(:id) { UUID }
      thing.define_singleton_method(:asset) { asset }
      thing.define_singleton_method(:first_available_locale) { 'de' }
      thing.define_singleton_method(:exif_property_names) { ['keywords', 'authors', 'categories', 'tags', 'blank_prop'] }
      thing.define_singleton_method(:property_definitions) do
        {
          'keywords' => { 'exif' => { 'keys' => ['Keywords'] } },
          'authors' => { 'type' => 'linked', 'exif' => { 'keys' => ['Headline'], 'prepend' => 'by ' } },
          'categories' => { 'type' => 'classification', 'exif' => { 'keys' => ['Subject'] } },
          'tags' => { 'type' => 'classification', 'exif' => { 'keys' => ['Caption'] } },
          'blank_prop' => { 'exif' => { 'keys' => ['Title'] } }
        }
      end
      thing.define_singleton_method(:keywords) { ['nature', 'sky'] }
      thing.define_singleton_method(:authors) { authors }
      thing.define_singleton_method(:categories) { categories }
      thing.define_singleton_method(:tags) { tags }
      thing.define_singleton_method(:blank_prop) { nil }
      thing.define_singleton_method(:name_property_selector) { |&_block| variant ? ['image_variants'] : [] }
      thing.define_singleton_method(:image_variants) { Array.wrap(variant) }
      thing
    end

    test 'returns when the thing has no asset' do
      thing = Object.new
      thing.define_singleton_method(:asset) { nil }

      DataCycleCore::Thing.stub(:find, thing) do
        assert_nil DataCycleCore::WriteExifDataJob.perform_now(UUID)
      end
    end

    test 'raises when the asset path cannot be resolved' do
      service = Object.new
      service.define_singleton_method(:path_for) { |_key| nil }
      file = Object.new
      file.define_singleton_method(:service) { service }
      file.define_singleton_method(:key) { 'key' }
      asset = Object.new
      asset.define_singleton_method(:file) { file }
      thing = thing_double(asset:)

      # ActiveRecord::RecordNotFound is in the job's discard_on list, so assert on
      # the underlying private method rather than through perform_now.
      assert_raises(ActiveRecord::RecordNotFound) { DataCycleCore::WriteExifDataJob.new.send(:update_exif_values, thing) }
    end

    test 'writes exif values across linked, classification and array properties' do
      exif = exif_double
      thing = thing_double(asset: asset_double)

      MiniExiftool.stub(:new, exif) do
        DataCycleCore::Thing.stub(:find, thing) do
          DataCycleCore::WriteExifDataJob.perform_now(UUID)
        end
      end

      # Keywords is one of EXIF_ARRAY_DATA_TYPES, so the array is kept as-is
      assert_equal ['nature', 'sky'], exif.store['Keywords']
      assert_equal 'by Jane', exif.store['Headline']
      assert_equal ['News'], exif.store['Subject']
      # Caption is not an array data type, so the array is joined into a string
      assert_equal 'Travel', exif.store['Caption']
    end

    test 'updates image variants with the collected exif values' do
      exif = exif_double
      invalidated = []
      variant_asset = asset_double
      variant = Object.new
      variant.define_singleton_method(:asset) { variant_asset }
      variant.define_singleton_method(:name) { 'Variant Headline' }
      variant.define_singleton_method(:invalidate_self) { invalidated << :done }
      thing = thing_double(asset: asset_double, variant:)

      MiniExiftool.stub(:new, exif) do
        DataCycleCore::Thing.stub(:find, thing) do
          DataCycleCore::WriteExifDataJob.perform_now(UUID)
        end
      end

      assert_equal [:done], invalidated
    end

    test 'does nothing further when the exif data did not change' do
      exif = exif_double(changed: false)
      thing = thing_double(asset: asset_double)

      MiniExiftool.stub(:new, exif) do
        DataCycleCore::Thing.stub(:find, thing) do
          assert_nil DataCycleCore::WriteExifDataJob.perform_now(UUID)
        end
      end
    end

    test 'swallows mini exiftool errors' do
      thing = thing_double(asset: asset_double)

      MiniExiftool.stub(:new, ->(*_args) { raise MiniExiftool::Error, 'broken' }) do
        DataCycleCore::Thing.stub(:find, thing) do
          assert_nil DataCycleCore::WriteExifDataJob.perform_now(UUID)
        end
      end
    end

    test 'exposes the reference id and priority' do
      job = DataCycleCore::WriteExifDataJob.new(UUID)

      assert_equal UUID, job.delayed_reference_id
      assert_equal DataCycleCore::WriteExifDataJob::PRIORITY, job.priority
    end
  end
end
