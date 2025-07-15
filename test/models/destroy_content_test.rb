# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DestroyContentTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @organization = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: 'Test Organisation 1' })
      @external_system = DataCycleCore::ExternalSystem.first

      I18n.with_locale(:de) do
        @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', author: [@organization.id] })
      end

      I18n.with_locale(:en) do
        @image.set_data_hash(data_hash: { name: 'Test Image 1' })
      end

      @article = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1', image: [@image.id] })
    end

    test 'delete a content' do
      assert_equal [:de, :en].to_set, @image.available_locales.to_set
      assert_equal 2, @image.searches.size
      assert_equal ['de', 'en'].to_set, @image.searches.pluck(:locale).to_set

      I18n.with_locale(:en) do
        @image.destroy(destroy_locale: true)
      end

      assert_equal [:de], @image.available_locales
      assert_equal 1, @image.searches.size
      assert_equal ['de'], @image.searches.pluck(:locale)
    end

    test 'delete linked images' do
      assert_equal(false, @image.destroyed?)

      @article.destroy(destroy_linked: { template_names: ['Bild'] })

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_raises(ActiveRecord::RecordNotFound) { @image.reload }
      assert_not(@organization.reload.destroyed?)
    end

    test 'dont delete linked without config' do
      assert_equal(false, @image.destroyed?)

      @article.destroy(destroy_linked: {})

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_not(@image.reload.destroyed?)
      assert_not(@organization.reload.destroyed?)
    end

    test 'dont delete linked with legacy config' do
      assert_equal(false, @image.destroyed?)

      @article.destroy(destroy_linked: true)

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_not(@image.reload.destroyed?)
      assert_not(@organization.reload.destroyed?)
    end

    test 'dont delete linked organizations from images' do
      assert_equal(false, @image.destroyed?)

      @article.destroy(destroy_linked: { template_names: ['Organization'] })

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_not(@image.reload.destroyed?)
      assert_not(@organization.reload.destroyed?)
    end

    test 'dont delete linked images with different external_source_id' do
      assert_equal(false, @image.destroyed?)

      @image.update_column(:external_source_id, @external_system.id)

      @article.destroy(destroy_linked: { template_names: ['Bild', 'Organization'] })

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_not(@image.reload.destroyed?)
      assert_not(@organization.reload.destroyed?)
    end

    test 'delete linked images with external_source_id, but not organization with same external_source_id' do
      assert_equal(false, @image.destroyed?)

      @image.update_column(:external_source_id, @external_system.id)

      @article.destroy(destroy_linked: { template_names: ['Bild', 'Organization'], external_system_ids: [@external_system.id] })

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_raises(ActiveRecord::RecordNotFound) { @image.reload }
      assert_not(@organization.reload.destroyed?)
    end

    test 'delete linked images with external_source_id and organization with same external_source_id' do
      assert_equal(false, @image.destroyed?)

      @image.update_column(:external_source_id, @external_system.id)

      @article.destroy(destroy_linked: { template_names: ['Bild', 'Organization'], external_system_ids: [@external_system.id, @article.external_source_id] })

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_raises(ActiveRecord::RecordNotFound) { @image.reload }
      assert_raises(ActiveRecord::RecordNotFound) { @organization.reload }
    end

    test 'delete linked images with collection_ids from stored_filter' do
      assert_equal(false, @image.destroyed?)

      collection = DataCycleCore::StoredFilter.new.parameters_from_hash(
        [
          { with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Bild'] } }
        ]
      ).tap(&:save!)

      @article.destroy(destroy_linked: { collection_ids: [collection.id] })

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_raises(ActiveRecord::RecordNotFound) { @image.reload }
      assert_not(@organization.reload.destroyed?)
    end

    test 'delete linked images with collection_ids from watch_list' do
      assert_equal(false, @image.destroyed?)

      collection = DataCycleCore::WatchList.create(full_path: 'Test List 1')
      collection.things << @image

      @article.destroy(destroy_linked: { collection_ids: [collection.id] })

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_raises(ActiveRecord::RecordNotFound) { @image.reload }
      assert_not(@organization.reload.destroyed?)
    end

    test 'dont delete linked existing relations' do
      assert_equal(false, @image.destroyed?)

      DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 2', image: [@image.id] })

      @article.destroy(destroy_linked: { template_names: ['Bild'] })

      assert(@article.destroyed?)
      assert_raises(ActiveRecord::RecordNotFound) { @article.reload }
      assert_not(@image.reload.destroyed?)
      assert_not(@organization.reload.destroyed?)
    end
  end
end
