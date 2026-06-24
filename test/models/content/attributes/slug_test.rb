# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class SlugTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @content = DataCycleCore::DataHashService.create_internal_object('Artikel', { datahash: { name: 'Test' } }, nil)
        end

        test 'correct slug is generated from name' do
          assert_equal 'test', @content.slug
        end

        test 'manually updating name does not change the slug' do
          @content.set_data_hash(data_hash: { name: 'Test 2' })

          assert_equal 'test', @content.slug
        end

        test 'manually updating slug does change it' do
          @content.set_data_hash(data_hash: { slug: 'test-2' })

          assert_equal 'test-2', @content.slug
        end

        test 'multiple content with the same name get unique incremented slugs' do
          base_name = 'Duplicate Name Test'
          first = DataCycleCore::DataHashService.create_internal_object('Artikel', { datahash: { name: base_name } }, nil)

          assert_equal 'duplicate-name-test', first.slug

          second = DataCycleCore::DataHashService.create_internal_object('Artikel', { datahash: { name: base_name } }, nil)

          assert_equal 'duplicate-name-test-1', second.slug

          third = DataCycleCore::DataHashService.create_internal_object('Artikel', { datahash: { name: base_name } }, nil)

          assert_equal 'duplicate-name-test-2', third.slug
        end

        test 'manually setting the same slug on multiple content increments correctly' do
          first = DataCycleCore::DataHashService.create_internal_object('Artikel', { datahash: { name: 'Slug Collision A' } }, nil)
          first.set_data_hash(data_hash: { slug: 'collision-slug' })

          assert_equal 'collision-slug', first.slug

          second = DataCycleCore::DataHashService.create_internal_object('Artikel', { datahash: { name: 'Slug Collision B' } }, nil)
          second.set_data_hash(data_hash: { slug: 'collision-slug' })

          assert_equal 'collision-slug-1', second.slug

          third = DataCycleCore::DataHashService.create_internal_object('Artikel', { datahash: { name: 'Slug Collision C' } }, nil)
          third.set_data_hash(data_hash: { slug: 'collision-slug' })

          assert_equal 'collision-slug-2', third.slug
        end

        test 'updating slug on existing content to its own slug does not increment' do
          content = DataCycleCore::DataHashService.create_internal_object('Artikel', { datahash: { name: 'Stable Slug Test' } }, nil)
          original_slug = content.slug

          content.set_data_hash(data_hash: { slug: original_slug })

          assert_equal original_slug, content.slug
        end

        test 'multiple content with same name generates up to 9 numbered suffixes then random' do
          base_name = 'High Collision Test'
          items = (0..10).map do
            DataCycleCore::DataHashService.create_internal_object('Artikel', { datahash: { name: base_name } }, nil)
          end

          assert_equal 'high-collision-test', items[0].slug
          1.upto(9) { |i| assert_equal "high-collision-test-#{i}", items[i].slug }
          assert_match(/\Ahigh-collision-test-[a-z0-9]{8}\z/, items[10].slug)
        end
      end
    end
  end
end
