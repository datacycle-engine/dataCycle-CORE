# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreativeWorksTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'create Artikel' do
      name = "test_artikel_#{Time.now.getutc.to_i}"
      post things_path, params: {
        thing: {
          datahash: {
            name: name,
            quotation: [
              {
                text: "test_zitat_#{Time.now.getutc.to_i}"
              }
            ]
          }
        },
        table: 'things',
        template: 'Artikel',
        locale: 'de'
      }, headers: {
        referer: root_path
      }

      content = DataCycleCore::Thing.find_by(name: name)

      assert_redirected_to edit_thing_path(content)
      assert_equal 1, content.quotation.size
      assert_equal I18n.t(:created, scope: [:controllers, :success], data: content.template_name, locale: DataCycleCore.ui_language), flash[:notice]
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
          datahash: @content.get_data_hash.merge('name' => updated_name)
        }
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_redirected_to thing_path(@content, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language), flash[:success]
      follow_redirect!
      assert_select '.detail-header > .title', updated_name
    end

    test 'show content history' do
      get thing_path(@content)
      assert_response :success
      assert_select '.detail-header > .title', @content.title

      get history_thing_path(@content, history_id: @content.histories&.first&.id)
      assert_response :success
      assert_select('.detail-content .type.properties .has-changes', count: 1)
    end

    test 'delete content' do
      delete thing_path(@content), params: {}, headers: {
        referer: thing_path(@content)
      }

      assert_redirected_to root_path
      assert_equal I18n.t(:destroyed, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language), flash[:success]

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
      quotations = []
      11.times do |i|
        linked_pois.push(DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: "TestPOI_#{i}" }))
        quotations.push({
          text: "TestQuotation_#{i}"
        })
      end

      valid = @content.set_data_hash(data_hash: {
        content_location: linked_pois.map(&:id),
        quotation: quotations
      }.deep_stringify_keys, partial_update: true)

      assert valid[:error].blank?

      get load_more_linked_objects_thing_path(@content), xhr: true, params: {
        definition: @content.schema.dig('properties', 'content_location'),
        key: 'content_location',
        load_more_action: 'show',
        locale: 'de',
        page: 2
      }, headers: {
        referer: thing_path(@content)
      }
      assert response.body.include?('load-more-linked-contents')
      assert(linked_pois[5..9].all? { |s| response.body.include?(s.name) })

      get load_more_linked_objects_thing_path(@content), xhr: true, params: {
        definition: @content.schema.dig('properties', 'content_location'),
        key: 'content_location',
        load_more_action: 'show',
        locale: 'de',
        page: 3
      }, headers: {
        referer: thing_path(@content)
      }
      assert response.body.exclude?('load-more-linked-contents')
      assert response.body.include?(linked_pois[10].name)

      get load_more_linked_objects_thing_path(@content), xhr: true, params: {
        definition: @content.schema.dig('properties', 'quotation'),
        key: 'quotation',
        load_more_action: 'show',
        locale: 'de',
        page: 2
      }, headers: {
        referer: thing_path(@content)
      }
      assert response.body.include?('load-more-linked-contents')
      assert(quotations[5..9].all? { |s| response.body.include?(s[:text]) })

      get load_more_linked_objects_thing_path(@content), xhr: true, params: {
        definition: @content.schema.dig('properties', 'quotation'),
        key: 'quotation',
        load_more_action: 'show',
        locale: 'de',
        page: 3
      }, headers: {
        referer: thing_path(@content)
      }
      assert response.body.exclude?('load-more-linked-contents')
      assert(response.body.include?(quotations.dig(10, :text)))

      get load_more_linked_objects_thing_path(@content), xhr: true, params: {
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
      assert response.body.include?('load-more-linked-contents')
      assert(linked_pois[5..9].all? { |s| response.body.include?(s.name) })

      get load_more_linked_objects_thing_path(@content), xhr: true, params: {
        definition: @content.schema.dig('properties', 'content_location'),
        complete_key: 'thing[datahash][content_location]',
        key: 'content_location',
        content_id: @content.id,
        content_type: 'things',
        load_more_action: 'object_browser',
        editable: true,
        locale: 'de',
        page: 3
      }, headers: {
        referer: edit_thing_path(@content)
      }
      assert response.body.exclude?('load-more-linked-contents')
      assert response.body.include?(linked_pois[10].name)

      get load_more_linked_objects_thing_path(@content), xhr: true, params: {
        definition: @content.schema.dig('properties', 'quotation'),
        complete_key: 'thing[datahash][quotation]',
        content_id: @content.id,
        content_type: 'things',
        editable: true,
        key: 'quotation',
        load_more_action: 'embedded_object',
        page: 2
      }, headers: {
        referer: edit_thing_path(@content)
      }
      assert response.body.include?('load-more-linked-contents')
      assert(quotations[5..9].all? { |s| response.body.include?(s[:text]) })

      get load_more_linked_objects_thing_path(@content), xhr: true, params: {
        definition: @content.schema.dig('properties', 'quotation'),
        complete_key: 'thing[datahash][quotation]',
        content_id: @content.id,
        content_type: 'things',
        editable: true,
        key: 'quotation',
        load_more_action: 'embedded_object',
        page: 3
      }, headers: {
        referer: edit_thing_path(@content)
      }
      assert response.body.exclude?('load-more-linked-contents')
      assert(response.body.include?(quotations.dig(10, :text)))
    end
  end
end
