# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    class ContentDuplicationTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
        @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

        person_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'api_person')
        gender_classification = DataCycleCore::Classification.find_by(name: 'Männlich')
        person_data_hash[:gender] = [gender_classification.id]
        person_data_hash[:image] = [@image.id]
        @person = DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: person_data_hash)

        @test_user = User.find_by(email: 'tester@datacycle.at')
      end

      # linked objects must be the same
      test 'test duplication with simple attributes and classifications' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_article')
        tag_classification = DataCycleCore::Classification.find_by(name: 'Tag 1')
        creative_work_data_hash[:tags] = [tag_classification.id]

        content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: creative_work_data_hash)

        new_content = DataCycleCore::DataHashService.create_duplicate(content:, current_user: @test_user)

        excepted_properties = ['id', 'slug']
        content_data_hash_properties = content.get_data_hash.except(*excepted_properties).merge('name' => "DUPLICATE: #{content.name}", 'headline' => "DUPLICATE: #{content.name}")
        assert_equal(content_data_hash_properties, new_content.get_data_hash.except(*excepted_properties))
      end

      # linked objects must be the same
      test 'test duplication with included objects' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_article')

        # validity_period
        validity_period = {
          'valid_from' => 10.days.ago.to_date,
          'valid_until' => 10.days.from_now.to_date
        }
        creative_work_data_hash[:validity_period] = validity_period

        content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: creative_work_data_hash)

        new_content = DataCycleCore::DataHashService.create_duplicate(content:, current_user: @test_user)

        excepted_properties = ['id', 'slug']
        content_data_hash_properties = content.get_data_hash.except(*excepted_properties).merge('name' => "DUPLICATE: #{content.name}", 'headline' => "DUPLICATE: #{content.name}")
        assert_equal(content_data_hash_properties, new_content.get_data_hash.except(*excepted_properties))
      end

      # linked objects must be the same
      test 'test duplication with linked objects' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_article')
        creative_work_data_hash['image'] = @image.id
        creative_work_data_hash['author'] = @person.id
        content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: creative_work_data_hash)

        new_content = DataCycleCore::DataHashService.create_duplicate(content:, current_user: @test_user)

        excepted_properties = ['id', 'author', 'image', 'slug']

        content_data_hash_properties = content.get_data_hash.except(*excepted_properties).merge('name' => "DUPLICATE: #{content.name}", 'headline' => "DUPLICATE: #{content.name}")
        assert_equal(content_data_hash_properties, new_content.get_data_hash.except(*excepted_properties))
        assert_equal(content.author.first.get_data_hash, new_content.author.first.get_data_hash)
        assert_equal(content.image.first.get_data_hash, new_content.image.first.get_data_hash)
      end

      test 'test duplication with embedded objects' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_quiz')
        content = DataCycleCore::TestPreparations.create_content(template_name: 'Quiz', data_hash: creative_work_data_hash)

        new_content = DataCycleCore::DataHashService.create_duplicate(content:, current_user: @test_user)

        excepted_properties = ['id', 'slug']
        content_data_hash_properties = content.get_data_hash.except(*excepted_properties).merge('name' => "DUPLICATE: #{content.name}", 'headline' => "DUPLICATE: #{content.name}")
        assert_not_equal(content_data_hash_properties, new_content.get_data_hash.except(*excepted_properties))
        assert_not_equal(content.question.first.id, new_content.question.first.id)

        assert_equal(content.get_data_hash.except(*(excepted_properties + ['question'])).merge('name' => "DUPLICATE: #{content.name}", 'headline' => "DUPLICATE: #{content.name}"), new_content.get_data_hash.except(*(excepted_properties + ['question'])))
      end

      test 'test duplication with assets' do
        @local_image = upload_image('test_rgb.jpeg')

        content_data_hash = {
          'name' => 'Test_ASSET',
          'asset' => @local_image.id
        }

        content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: content_data_hash)

        new_content = DataCycleCore::DataHashService.create_duplicate(content:, current_user: @test_user)

        excepted_properties = ['id', 'slug'] + content.asset_property_names + content.computed_property_names

        content_data_hash_properties = content.get_data_hash.except(*excepted_properties).merge('name' => "DUPLICATE: #{content.name}")
        assert_equal(content_data_hash_properties, new_content.get_data_hash.except(*excepted_properties))
        assert_nil(new_content.asset)
        content.computed_property_names.each do |computed_property|
          assert(new_content.send(computed_property.to_sym).blank?)
        end
      end

      # linked objects must be the same
      test 'test duplication with simple attributes, classifications, included objects and linked objects in mulitple languages' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_article')
        tag_classification = DataCycleCore::Classification.find_by(name: 'Tag 1')
        creative_work_data_hash[:tags] = [tag_classification.id]

        # validity_period
        validity_period = {
          'valid_from' => 10.days.ago.to_date,
          'valid_until' => 10.days.from_now.to_date
        }
        creative_work_data_hash[:validity_period] = validity_period
        creative_work_data_hash['image'] = @image.id
        creative_work_data_hash['author'] = @person.id

        content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: creative_work_data_hash)

        # translation
        translated_data_hash = content.get_data_hash
        I18n.with_locale(:en) do
          content.save
          translated_data_hash['name'] = 'EN NAME'
          translated_data_hash['alternative_headline'] = 'EN ALTERNATIVE NAME'
          content.set_data_hash(data_hash: translated_data_hash, current_user: @test_user)
          content.reload
        end

        assert_equal(2, content.translations.count)

        new_content = DataCycleCore::DataHashService.create_duplicate(content:, current_user: @test_user)

        excepted_properties = ['id', 'author', 'image', 'slug']

        I18n.with_locale(:de) do
          content_data_hash_properties = content.get_data_hash.except(*excepted_properties).merge('name' => "DUPLICATE: #{content.name}", 'headline' => "DUPLICATE: #{content.name}")
          assert_equal(content_data_hash_properties, new_content.get_data_hash.except(*excepted_properties))
          assert_equal(content.author.first.get_data_hash, new_content.author.first.get_data_hash)
          assert_equal(content.image.first.get_data_hash, new_content.image.first.get_data_hash)
        end

        I18n.with_locale(:en) do
          content_data_hash_properties = content.get_data_hash.except(*excepted_properties).merge('name' => "DUPLICATE: #{content.name}", 'headline' => "DUPLICATE: #{content.name}")
          assert_equal(content_data_hash_properties, new_content.get_data_hash.except(*excepted_properties))
        end

        assert_equal([:de], new_content.author.first.available_locales)
        assert_equal([:de], new_content.image.first.available_locales)
      end

      test 'test duplication with embedded objects in multiple languages' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_quiz')
        content = DataCycleCore::TestPreparations.create_content(template_name: 'Quiz', data_hash: creative_work_data_hash)

        # translation
        translated_data_hash = content.get_data_hash
        I18n.with_locale(:en) do
          content.save
          translated_data_hash['name'] = 'EN NAME'
          translated_data_hash['alternative_headline'] = 'EN ALTERNATIVE NAME'
          content.set_data_hash(data_hash: translated_data_hash, current_user: @test_user)
          content.reload
        end

        assert_equal(2, content.translations.count)

        new_content = DataCycleCore::DataHashService.create_duplicate(content:, current_user: @test_user)

        excepted_properties = ['id', 'slug']

        I18n.with_locale(:de) do
          content_data_hash_properties = content.get_data_hash.except(*excepted_properties).merge('name' => "DUPLICATE: #{content.name}", 'headline' => "DUPLICATE: #{content.name}")
          assert_not_equal(content_data_hash_properties, new_content.get_data_hash.except(*excepted_properties))
          assert_not_equal(content.question.first.id, new_content.question.first.id)
          assert_equal(content_data_hash_properties.except('question'), new_content.get_data_hash.except(*(excepted_properties + ['question'])))
        end

        I18n.with_locale(:en) do
          content_data_hash_properties = content.get_data_hash.except(*excepted_properties).merge('name' => "DUPLICATE: #{content.name}", 'headline' => "DUPLICATE: #{content.name}")
          assert_not_equal(content_data_hash_properties, new_content.get_data_hash.except(*excepted_properties))
          assert_not_equal(content.question.first.id, new_content.question.first.id)
          assert_equal(content_data_hash_properties.except('question'), new_content.get_data_hash.except(*(excepted_properties + ['question'])))
        end

        # 3 embedded * 2 contents * 2 translations = 12 + embedded created in setup
        assert_equal(13, DataCycleCore::ContentContent.count)
      end

      def teardown
        # return if @local_image&.id.blank?
        # @local_image.remove_file!
      end
    end
  end
end
