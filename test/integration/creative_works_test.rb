# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreativeWorksTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      DataCycleCore::Thing.delete_all
      @content = create_content('Artikel', { name: 'TestArtikel' })
    end

    setup do
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    # TODO: add embedded test
    test 'create Artikel' do
      name = "test_artikel_#{Time.now.getutc.to_i}"
      post things_path, params: {
        thing: {
          datahash: {
            name:
            # quotation: [
            #   {
            #     text: "test_zitat_#{Time.now.getutc.to_i}"
            #   }
            # ]
          }
        },
        table: 'things',
        template: 'Artikel',
        locale: 'de'
      }, headers: {
        referer: root_path
      }

      content = DataCycleCore::Thing.where_translated_value(name:).first

      assert_redirected_to edit_thing_path(content)
      # assert_equal 1, content.quotation.size
      assert_equal I18n.t('controllers.success.created', data: content.template_name, locale: DataCycleCore.ui_locales.first), flash[:success]
    end

    test 'search content by fulltext' do
      get root_path, params: {
        utf8: '✓',
        f: {
          s: {
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => 'TestArtikel'
          }
        },
        language: ['de']
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestArtikel'
    end

    test 'update content' do
      updated_name = "updated_test_artikel_#{Time.now.getutc.to_i}"

      patch thing_path(@content), params: {
        thing: {
          translations: {
            I18n.locale => {
              'name' => updated_name
            }
          }
        },
        save_and_close: true
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_redirected_to thing_path(@content, locale: I18n.locale)
      assert_equal I18n.t('controllers.success.updated', data: @content.template_name, locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!

      assert_select ".detail-header > .title > .translatable-attribute-container > .translatable-attribute.#{I18n.locale}", 1
    end

    test 'show content history' do
      get thing_path(@content)

      @content.set_data_hash(data_hash: {
        name: 'changed name'
      }.deep_stringify_keys, partial_update: true)

      assert_response :success
      assert_select ".detail-header > .title > .translatable-attribute-container > .translatable-attribute.#{I18n.locale}", 1
      get history_thing_path(@content, history_id: @content.histories&.first&.id)

      assert_response :success
      assert_select('.detail-content .type.properties .has-changes', count: 1) # title & slug
    end

    # Redmine #41458: the diff viewer resolves added concepts through HistoryHelper#new_relations,
    # which builds the model from a plain table string - a stale 'classifications' there
    # constantizes to the deleted DataCycleCore::Classification, and #history turns the NameError
    # into a redirect. Only a classification attribute gaining a value walks that branch.
    test 'show content history with an added concept' do
      concept = DataCycleCore::Concept.for_tree('Tags').with_internal_name('Tag 1').first

      assert_not_nil concept

      history_ids = @content.histories.pluck(:id)
      @content.set_data_hash(data_hash: { 'tags' => [concept.id] }, partial_update: true)
      new_history_ids = @content.histories.reload.pluck(:id) - history_ids

      assert_equal 1, new_history_ids.size

      get history_thing_path(@content, history_id: new_history_ids.first)

      assert_response :success
      assert_select('.detail-content.tags .tag.has-changes.new', text: /Tag 1/)
    end

    # Redmine #41458: a publication's concept changes are navigated out of the publication-level
    # diff computed above the loop, the way date_changes reads it for publish_at. Resetting that
    # diff per attribute left attribute_changes nothing to navigate, so an added channel never
    # reached the row.
    test 'show content history with a changed concept on an embedded publication schedule' do
      initial_channel, added_channel = DataCycleCore::Concept.for_tree('Ausgabekanäle').first(2)

      assert_not_nil added_channel

      @content.set_data_hash(data_hash: {
        'publication_schedule' => [{
          'template_name' => 'Publikations-Plan',
          'publish_at' => Time.zone.today.to_s,
          'output_channel' => [initial_channel.id]
        }]
      }, partial_update: true)

      publication = @content.reload.publication_schedule.first
      history_ids = @content.histories.pluck(:id)

      @content.set_data_hash(data_hash: {
        'publication_schedule' => [{
          'id' => publication.id,
          'template_name' => 'Publikations-Plan',
          'publish_at' => Time.zone.today.to_s,
          'output_channel' => [initial_channel.id, added_channel.id]
        }]
      }, partial_update: true)
      new_history_ids = @content.histories.reload.pluck(:id) - history_ids

      assert_equal 1, new_history_ids.size

      get history_thing_path(@content, history_id: new_history_ids.first)

      assert_response :success
      assert_select('.publication-row .tag.has-changes.new', count: 1, text: added_channel.internal_name)
      assert_select('.publication-row .tag', text: initial_channel.internal_name)
    end

    test 'delete content' do
      delete thing_path(@content), params: {}, headers: {
        referer: thing_path(@content)
      }

      assert_redirected_to root_path
      assert_equal I18n.t('controllers.success.destroyed', data: @content.template_name, locale: DataCycleCore.ui_locales.first), flash[:success]

      get root_path, params: {
        utf8: '✓',
        f: {
          s: {
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => 'TestArtikel'
          }
        },
        language: ['de']
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', { count: 0, text: 'TestArtikel' }
    end

    test 'load more contents - show' do
      linked_pois = []
      # quotations = []
      11.times do |i|
        linked_pois.push(DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: "TestPOI_#{i}" }))
        # quotations.push({
        #   text: "TestQuotation_#{i}"
        # })
      end

      valid = @content.set_data_hash(data_hash: {
        content_location: linked_pois.map(&:id)
        # quotation: quotations
      }.deep_stringify_keys, partial_update: true)

      assert valid

      post load_more_linked_objects_thing_path(@content), xhr: true, params: {
        definition: @content.schema.dig('properties', 'content_location'),
        key: 'content_location',
        load_more_action: 'show',
        locale: 'de',
        content_id: @content.id,
        content_type: 'things',
        page: 2
      }, headers: {
        referer: thing_path(@content)
      }

      assert(linked_pois[5..10].all? { |s| response.body.include?(s.name) })

      post load_more_linked_objects_thing_path(@content), xhr: true, params: {
        definition: @content.schema.dig('properties', 'content_location'),
        complete_key: 'thing[datahash][content_location]',
        key: 'content_location',
        content_id: @content.id,
        content_type: 'things',
        load_more_action: 'object_browser',
        editable: true,
        locale: 'de',
        page: 2
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert(linked_pois[5..10].all? { |s| response.body.include?(s.name) })
    end

    # TODO: fix test (fails sometimes)
    # DataCycleCore::CreativeWorksTest#test_load_related_contents [/builds/data-cycle/data-cycle-core/test/integration/creative_works_test.rb:270]:
    # Expected false to be truthy.
    # bin/rails test test/integration/creative_works_test.rb:252
    # test 'load related contents' do
    #   poi = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'TestPOI' })
    #   contents = []
    #   11.times do |i|
    #     contents.push(DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: "TestArtikel_#{i}", content_location: [poi.id] }))
    #   end
    #
    #   contents.sort_by!(&:id)
    #
    #   assert_equal 11, poi.related_contents.size
    #
    #   get load_more_related_thing_path(poi), xhr: true, params: {
    #     page: 2
    #   }, headers: {
    #     referer: thing_path(poi)
    #   }
    #   assert response.body.include?('load-more-related-button')
    #   assert(contents[5..9].all? { |s| I18n.with_locale(s.first_available_locale) { response.body.include?(s.title) } })
    #   assert(I18n.with_locale(contents.last.first_available_locale) { response.body.exclude?(contents.last.title) })
    #
    #   get load_more_related_thing_path(poi), xhr: true, params: {
    #     page: 3
    #   }, headers: {
    #     referer: thing_path(poi)
    #   }
    #   assert(I18n.with_locale(contents.last.first_available_locale) { response.body.include?(contents.last.title) })
    # end
  end
end
