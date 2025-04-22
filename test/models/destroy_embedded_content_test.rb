# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DestroyEmbeddedContentTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @article = DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: {
          name: 'Test Artikel 1',
          potential_action: [{ name: 'Test Action', url: 'https://example.com' }]
        }
      )
      @article2 = DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: { name: 'Test Artikel 2' }
      )
      @embedded = @article.potential_action.first
      @translated_content = DataCycleCore::TestPreparations.create_content(
        template_name: 'Embedded-With-Translations',
        data_hash: {
          name: 'Test Dummy 1',
          embedded_creative_work: [{ name: 'Test Action' }],
          embedded_translated_creative_work: [{ name: 'Test Action' }]
        }
      )
      @embedded_creative_work_de = @translated_content.embedded_creative_work.first
      @embedded_translated_creative_work = @translated_content.embedded_translated_creative_work.first
      I18n.with_locale(:en) do
        @translated_content.set_data_hash(
          data_hash: {
            name: 'Test Dummy 1 en',
            embedded_creative_work: [{ name: 'Test Action en' }],
            embedded_translated_creative_work: [{ id: @embedded_translated_creative_work.id, name: 'Test Action en' }]
          }
        )
        @embedded_creative_work_en = @translated_content.embedded_creative_work.first
      end

      @translated_content2 = DataCycleCore::TestPreparations.create_content(
        template_name: 'Embedded-With-Translations',
        data_hash: { name: 'Test Dummy 2' }
      )
      I18n.with_locale(:en) do
        @translated_content2.set_data_hash(data_hash: { name: 'Test Dummy 2 en' })
      end
    end

    test 'delete a content and embedded' do
      @article.destroy

      assert_raises ActiveRecord::RecordNotFound do
        @article.reload
        @embedded.reload
      end
    end

    test 'delete embedded, when removed from content' do
      @article.set_data_hash(data_hash: { potential_action: [] })

      assert_raises ActiveRecord::RecordNotFound do
        @embedded.reload
      end
    end

    test 'embedded only gets deleted, after all parents are destroyed' do
      @article2.set_data_hash(data_hash: { potential_action: [{ id: @embedded.id }] })
      @article.destroy

      assert_nothing_raised do
        @embedded.reload
      end

      @article2.destroy
      assert_raises ActiveRecord::RecordNotFound do
        @embedded.reload
      end
    end

    test 'embedded only gets deleted, after all parent relations get destroyed' do
      @article2.set_data_hash(data_hash: { potential_action: [{ id: @embedded.id }] })
      @article.set_data_hash(data_hash: { potential_action: [] })
      assert_nothing_raised do
        @embedded.reload
      end

      @article2.set_data_hash(data_hash: { potential_action: [] })
      assert_raises ActiveRecord::RecordNotFound do
        @embedded.reload
      end
    end

    test 'embedded translations get deleted correctly on destroy_locale en' do
      I18n.with_locale(:en) do
        @translated_content.destroy(destroy_locale: true)
      end

      assert_nothing_raised do
        @translated_content.reload
        @embedded_translated_creative_work.reload
        @embedded_creative_work_de.reload
      end

      assert_equal [:de], @embedded_translated_creative_work.reload.available_locales

      assert_raises ActiveRecord::RecordNotFound do
        @embedded_creative_work_en.reload
      end
    end

    test 'embedded translations get deleted correctly on destroy_locale de' do
      I18n.with_locale(:de) do
        @translated_content.destroy(destroy_locale: true)
      end

      assert_nothing_raised do
        I18n.with_locale(:en) do
          @translated_content.reload
          @embedded_translated_creative_work.reload
          @embedded_creative_work_en.reload
        end
      end

      assert_equal [:en], @embedded_translated_creative_work.reload.available_locales

      assert_raises ActiveRecord::RecordNotFound do
        @embedded_creative_work_de.reload
      end
    end

    test 'embedded translations dont get deleted on destroy_locale de with multiple relations' do
      @translated_content2.set_data_hash(data_hash: {
        embedded_creative_work: [{ id: @embedded_creative_work_de.id }],
        embedded_translated_creative_work: [{ id: @embedded_translated_creative_work.id }]
      })

      I18n.with_locale(:de) do
        @translated_content.destroy(destroy_locale: true)
      end

      assert_equal [:de, :en], @embedded_translated_creative_work.reload.available_locales

      assert_nothing_raised do
        I18n.with_locale(:en) do
          @translated_content.reload
          @embedded_translated_creative_work.reload
          @embedded_creative_work_en.reload
        end

        @embedded_creative_work_de.reload
      end
    end

    test 'embedded translations dont get deleted on destroy_locale en with multiple relations' do
      @translated_content2.set_data_hash(data_hash: {
        embedded_creative_work: [{ id: @embedded_creative_work_de.id }],
        embedded_translated_creative_work: [{ id: @embedded_translated_creative_work.id }]
      })

      I18n.with_locale(:en) do
        @translated_content.destroy(destroy_locale: true)
        @translated_content2.destroy(destroy_locale: true)
      end

      assert_equal [:de], @embedded_translated_creative_work.reload.available_locales

      assert_nothing_raised do
        @translated_content.reload
        @embedded_translated_creative_work.reload
        @embedded_creative_work_de.reload
      end

      assert_raises ActiveRecord::RecordNotFound do
        @embedded_creative_work_en.reload
      end
    end

    test 'embedded relations dont get removed, when relation is removed in one locale' do
      @translated_content.set_data_hash(data_hash: {
        embedded_creative_work: [],
        embedded_translated_creative_work: []
      })

      I18n.with_locale(:de) do
        assert(@translated_content.embedded_creative_work.blank?)
        assert(@translated_content.embedded_translated_creative_work.blank?)
      end

      I18n.with_locale(:en) do
        assert(@translated_content.embedded_creative_work.present?)
        assert(@translated_content.embedded_translated_creative_work.blank?)
      end
    end
  end
end
