# frozen_string_literal: true

require 'test_helper'
require 'rake_helpers/content_helper'

module DataCycleCore
  # Named RakeContentHelperTest (not ContentHelperTest) to avoid a constant clash
  # with the view-helper test DataCycleCore::ContentHelperTest in test/helpers/.
  # This exercises the rake helper ::ContentHelper (require'd above).
  class RakeContentHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'find_or_create_content creates a new content when none exists' do
      content = ::ContentHelper.find_or_create_content(
        external_source: nil,
        external_key: 'content-helper-test-1',
        template_name: 'POI',
        data: { name: 'Content Helper POI' }
      )

      assert_predicate content, :persisted?
      assert_equal 'POI', content.template_name
      assert_equal 'content-helper-test-1', content.external_key
      assert_equal 'Content Helper POI', content.name
    end

    test 'find_or_create_content returns the existing content on a second call' do
      first = ::ContentHelper.find_or_create_content(
        external_source: nil,
        external_key: 'content-helper-test-2',
        template_name: 'POI',
        data: { name: 'Existing POI' }
      )

      second = ::ContentHelper.find_or_create_content(
        external_source: nil,
        external_key: 'content-helper-test-2',
        template_name: 'POI',
        data: { name: 'Should be ignored' }
      )

      assert_equal first.id, second.id
    end

    # Anchors the rule stated at lib/rake_helpers/content_helper.rb#comparable_text: a migration
    # that moved a text somewhere else has to recognise it again, and the editor's copy of the same
    # prose differs from the imported one in entities and whitespace only.
    test 'comparable_text sees the same prose through markup, entities and whitespace' do
      assert_equal ::ContentHelper.comparable_text('<p>a b</p>'), ::ContentHelper.comparable_text('<p>a&nbsp;b</p>')
      assert_equal ::ContentHelper.comparable_text('<p>a b</p>'), ::ContentHelper.comparable_text("<p>a\u00A0b</p>")
      assert_equal ::ContentHelper.comparable_text('<p>a b</p>'), ::ContentHelper.comparable_text("  <p>a\n\n  b</p>  ")
      assert_equal 'a b', ::ContentHelper.comparable_text('<p>a&nbsp;<strong>b</strong></p>')
    end

    test 'comparable_text keeps different prose apart and reduces empty markup to nil' do
      assert_not_equal ::ContentHelper.comparable_text('<p>Styling des Widgets</p>'), ::ContentHelper.comparable_text('<p>Erscheinungsbild im Corporate Design</p>')
      assert_nil ::ContentHelper.comparable_text('<p></p>')
      assert_nil ::ContentHelper.comparable_text('<p>&nbsp;</p>')
      assert_nil ::ContentHelper.comparable_text(nil)
    end
  end

  # What the dc:update_data back-fills run over. Their own loops cannot be tested here (they fork
  # per batch), so the selection they fork over is pinned instead.
  class BackfillScopeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @external_system = DataCycleCore::ExternalSystem.find_or_create_by!(name: 'Backfill Scope System', identifier: 'backfill-scope-system')

      @imported_poi = ::ContentHelper.find_or_create_content(
        external_source: @external_system,
        external_key: 'backfill-scope-poi',
        template_name: 'POI',
        data: { name: 'Backfill Scope Imported POI' }
      )
      @imported_organization = ::ContentHelper.find_or_create_content(
        external_source: @external_system,
        external_key: 'backfill-scope-organization',
        template_name: 'Organization',
        data: { name: 'Backfill Scope Imported Organization' }
      )
      @editorial_poi = ::ContentHelper.find_or_create_content(
        template_name: 'POI',
        data: { name: 'Backfill Scope Editorial POI' }
      )
    end

    after(:all) do
      [@imported_poi, @imported_organization, @editorial_poi].each { |content| content&.destroy_content(save_history: false) }
      @external_system&.destroy
    end

    test 'backfill_scope without arguments runs over every template and every content' do
      scope = ::ContentHelper.backfill_scope

      assert_equal DataCycleCore::ThingTemplate.count, scope.thing_templates.count
      assert_equal DataCycleCore::Thing.count, scope.things.count
    end

    test 'backfill_scope narrows the templates to the names it is given' do
      scope = ::ContentHelper.backfill_scope(templates_or_collection_id: ['POI'])

      assert_equal ['POI'], scope.thing_templates.pluck(:template_name)
      assert_equal DataCycleCore::Thing.count, scope.things.count
    end

    test 'backfill_scope narrows contents and templates to one external system' do
      scope = ::ContentHelper.backfill_scope(external_system: 'backfill-scope-system')

      assert_equal [@imported_organization.id, @imported_poi.id].sort, scope.things.pluck(:id).sort
      assert_equal ['Organization', 'POI'], scope.thing_templates.pluck(:template_name).sort
    end

    # The two narrow different halves: a template name narrows the templates walked, and the task
    # intersects the two itself with `things.where(template_name: template.template_name)` per
    # template. So the contents of the other template are still in `things` and never reached.
    test 'backfill_scope applies a template name and an external system together' do
      scope = ::ContentHelper.backfill_scope(templates_or_collection_id: ['POI'], external_system: 'Backfill Scope System')

      assert_equal ['POI'], scope.thing_templates.pluck(:template_name)
      assert_equal [@imported_poi.id], scope.things.where(template_name: 'POI').pluck(:id)
      assert_not_includes scope.things.pluck(:id), @editorial_poi.id
    end

    # A typo must not silently back-fill every content: the imageDescriptionPixie of #49225 pays a
    # vision service per image, so the scope this returns is a bill.
    test 'backfill_scope raises for an external system that does not exist' do
      error = assert_raises(RuntimeError) { ::ContentHelper.backfill_scope(external_system: 'backfill-scope-typo') }

      assert_match(/not found/, error.message)
    end

    test 'backfill_scope resolves a collection id to the contents it holds' do
      collection = DataCycleCore::WatchList.create!(full_path: 'Backfill Scope Collection')
      collection.things << @editorial_poi

      scope = ::ContentHelper.backfill_scope(templates_or_collection_id: [collection.id])

      assert_equal [@editorial_poi.id], scope.things.pluck(:id)
      assert_equal ['POI'], scope.thing_templates.pluck(:template_name)
    ensure
      collection&.destroy
    end
  end
end
