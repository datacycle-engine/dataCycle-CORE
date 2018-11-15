# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class FeatureContainerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'LifeCycleTestArtikel' })
      @container = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: { name: 'TestContainer' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'change life_cycle_stage to including children' do
      stages = DataCycleCore::Feature::LifeCycle.ordered_classifications(@container)

      @content.update({ is_part_of: @container.id })

      patch polymorphic_path([:update_life_cycle, @container]), params: {
        life_cycle: {
          id: stages.values.last[:id],
          name: stages.keys.last
        }
      }, headers: {
        referer: polymorphic_path(@container)
      }

      assert_redirected_to polymorphic_path(@container)
      follow_redirect!

      assert @container.reload.life_cycle_stage?(stages.values.last[:id])
      assert @content.reload.life_cycle_stage?(stages.values.last[:id])
    end

    test 'create content inside container' do
      name = "test_artikel_#{Time.now.getutc.to_i}"

      post things_path, params: {
        thing: {
          datahash: {
            name: name
          }
        },
        table: 'things',
        template: 'Artikel',
        locale: 'de',
        parent_id: @container.id
      }

      child = DataCycleCore::Thing.find_by(name: name)

      assert child
      assert_equal(child.parent.id, @container.id)
    end

    test 'delete container with child' do
      @content.update({ is_part_of: @container.id })

      delete polymorphic_path(@container), params: {}, headers: {
        referer: polymorphic_path(@container)
      }

      assert_redirected_to root_path
      assert_equal 'Container wurde gelöscht.', flash[:success]

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

      get root_path, params: {
        utf8: '✓',
        f: {
          s: {
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => 'TestContainer'
          }
        },
        language: ['de']
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', { count: 0, text: 'TestContainer' }
    end
  end
end
