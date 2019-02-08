# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    class ContentDuplicationTest < ActiveSupport::TestCase
      setup do
        image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
        @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

        person_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'api_person')
        gender_classification = DataCycleCore::Classification.find_by(name: 'Männlich')
        person_data_hash[:gender] = [gender_classification.id]
        person_data_hash[:image] = [@image.id]
        @person = DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: person_data_hash)
      end

      # linked objects must be the same
      test 'test duplication with simple attributes and classifications' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_article')
        tag_classification = DataCycleCore::Classification.find_by(name: 'Tag 1')
        creative_work_data_hash[:tags] = [tag_classification.id]

        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: creative_work_data_hash)

        new_content_datahash = @content.get_data_hash
        new_content = DataCycleCore::Thing.find_by(template_name: 'Artikel', template: true).dup
        new_content.template = false
        new_content.save!

        I18n.with_locale(:de) do
          new_content.set_data_hash(data_hash: new_content_datahash, new_content: true, current_user: User.find_by(email: 'tester@datacycle.at'))
        end
        new_content.reload

        excepted_properties = ['id']
        assert_equal(@content.get_data_hash.except(*excepted_properties), new_content.get_data_hash.except(*excepted_properties))
      end

      # linked objects must be the same
      test 'test duplication with included objects' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_article')

        # validity_period
        validity_period = {
          'valid_from' => 10.days.ago,
          'valid_until' => 10.days.from_now
        }
        creative_work_data_hash[:validity_period] = validity_period

        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: creative_work_data_hash)

        new_content_datahash = @content.get_data_hash
        new_content = DataCycleCore::Thing.find_by(template_name: 'Artikel', template: true).dup
        new_content.template = false
        new_content.save!

        I18n.with_locale(:de) do
          new_content.set_data_hash(data_hash: new_content_datahash, new_content: true, current_user: User.find_by(email: 'tester@datacycle.at'))
        end
        new_content.reload

        excepted_properties = ['id']
        assert_equal(@content.get_data_hash.except(*excepted_properties), new_content.get_data_hash.except(*excepted_properties))
      end

      # linked objects must be the same
      test 'test duplication with linked objects' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_article')
        creative_work_data_hash['image'] = @image.id
        creative_work_data_hash['author'] = @person.id
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: creative_work_data_hash)

        new_content_datahash = @content.get_data_hash
        new_content = DataCycleCore::Thing.find_by(template_name: 'Artikel', template: true).dup
        new_content.template = false
        new_content.save!
        I18n.with_locale(:de) do
          new_content.set_data_hash(data_hash: new_content_datahash, new_content: true, current_user: User.find_by(email: 'tester@datacycle.at'))
        end
        new_content.reload

        excepted_properties = ['id', 'author', 'image']
        assert_equal(@content.get_data_hash.except(*excepted_properties), new_content.get_data_hash.except(*excepted_properties))
        assert_equal(@content.author.first.get_data_hash, new_content.author.first.get_data_hash)
        assert_equal(@content.image.first.get_data_hash, new_content.image.first.get_data_hash)
      end

      test 'test duplication with embedded objects' do
        creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_quiz')
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Quiz', data_hash: creative_work_data_hash)

        new_content_datahash = @content.duplicate_contents(@content.get_data_hash)

        new_content = DataCycleCore::Thing.find_by(template_name: 'Quiz', template: true).dup
        new_content.template = false
        new_content.save!
        I18n.with_locale(:de) do
          new_content.set_data_hash(data_hash: new_content_datahash, new_content: true, current_user: User.find_by(email: 'tester@datacycle.at'))
        end
        new_content.reload

        excepted_properties = ['id']
        assert_not_equal(@content.get_data_hash.except(*excepted_properties), new_content.get_data_hash.except(*excepted_properties))
        assert_not_equal(@content.question.first.id, new_content.question.first.id)

        assert_equal(@content.get_data_hash.except(*(excepted_properties + ['question'])), new_content.get_data_hash.except(*(excepted_properties + ['question'])))
      end

      test 'test duplication with embedded assets' do
        file_name = 'test_rgb.jpg'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @image = DataCycleCore::Image.new(file: File.open(file_path))
        @image.save
        @image.reload

        embedded_image = {
          'caption' => 'Caption',
          'text' => 'Text',
          'asset' => @image.id
        }

        inhalts_block_1 = {
          'name' => 'Inhaltsblock 1',
          'text' => 'Text 1'
        }
        inhalts_block_2 = {
          'name' => 'Inhaltsblock 2',
          'text' => 'Text 2'
        }

        article_w_embedded_asset = {
          'name' => 'Article_w_embedded_asset',
          'thumbnail' => [embedded_image],
          'content_block' => [inhalts_block_1, inhalts_block_2]
        }

        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Article-w-embedded-asset', data_hash: article_w_embedded_asset)

        new_content_datahash = @content.duplicate_contents(@content.get_data_hash)
        byebug
        new_content = DataCycleCore::Thing.find_by(template_name: 'Quiz', template: true).dup
        new_content.template = false
        new_content.save!
        I18n.with_locale(:de) do
          new_content.set_data_hash(data_hash: new_content_datahash, new_content: true, current_user: User.find_by(email: 'tester@datacycle.at'))
        end
        new_content.reload

        excepted_properties = ['id']
        assert_not_equal(@content.get_data_hash.except(*excepted_properties), new_content.get_data_hash.except(*excepted_properties))
        assert_not_equal(@content.question.first.id, new_content.question.first.id)

        assert_equal(@content.get_data_hash.except(*(excepted_properties + ['question'])), new_content.get_data_hash.except(*(excepted_properties + ['question'])))
      end

      # w translations
      # test 'test duplication with linked objects' do
      #   translated_data_hash = @content.get_data_hash
      #   I18n.with_locale(:en) do
      #     @content.save
      #     translated_data_hash['name'] = 'EN NAME'
      #     translated_data_hash['alternative_headline'] = 'EN ALTERNATIVE NAME'
      #     @content.set_data_hash(data_hash: translated_data_hash, current_user: User.find_by(email: 'tester@datacycle.at'))
      #     @content.reload
      #   end
      #
      #   new_content_datahash = @content.get_data_hash
      #
      #   new_content_translated_datahash = ''
      #   I18n.with_locale(:en) do
      #     new_content_translated_datahash = @content.get_data_hash
      #   end
      #
      #   new_content = DataCycleCore::Thing.find_by(template_name: 'Artikel', template: true).dup
      #   new_content.template = false
      #   new_content.save!
      #
      #   I18n.with_locale(:de) do
      #     new_content.set_data_hash(data_hash: new_content_datahash, new_content: true, current_user: User.find_by(email: 'tester@datacycle.at'))
      #   end
      #
      #   I18n.with_locale(:en) do
      #     new_content.save
      #     new_content.set_data_hash(data_hash: new_content_translated_datahash, current_user: User.find_by(email: 'tester@datacycle.at'))
      #   end
      #   new_content.reload
      #
      #   excepted_properties = ['id', 'author']
      #   assert_equal(@content.get_data_hash.except(*excepted_properties), new_content.get_data_hash.except(*excepted_properties))
      #   assert_equal(@content.author.first.get_data_hash, new_content.author.first.get_data_hash)
      #
      #   I18n.with_locale(:en) do
      #     assert_equal(@content.get_data_hash.except(*excepted_properties), new_content.get_data_hash.except(*excepted_properties))
      #     assert_equal(@content.author.first.get_data_hash, new_content.author.first.get_data_hash)
      #   end
      # end
      #
    end
  end
end
