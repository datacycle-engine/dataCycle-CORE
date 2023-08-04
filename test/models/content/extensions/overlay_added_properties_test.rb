# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class OverlayAddedPropertiesTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include ActiveJob::TestHelper

    def create_thing
      DataCycleCore::TestPreparations.create_content(template_name: 'Thing-With-Overlay', data_hash: { name: 'Test-Thing-With-Overlay' })
    end

    def update_thing(thing, data_hash)
      thing.set_data_hash(data_hash:, partial_update: true, prevent_history: true)
      thing
    end

    def create_thing_with_overlay
      item = create_thing
      update_thing(item, { overlay: [{ name: 'Test Overlay', description: 'Description' }] })
    end

    def create_thing_with_simple_object
      item = create_thing
      update_thing(item, {
        overlay: [{
          name: 'Test Overlay',
          validity_period: { valid_from: '1.1.2000', valid_until: '1.1.2010' }
        }]
      })
    end

    def create_thing_with_embedded
      item = create_thing
      update_thing(item, {
        overlay: [{
          name: 'Test Overlay',
          embedded: [{ name: 'Test Embedded' }]
        }]
      })
    end

    def create_thing_with_linked(image)
      item = create_thing
      update_thing(item, {
        overlay: [{
          name: 'Test Overlay',
          linked: [image.id]
        }]
      })
    end

    test 'overwriten name, added description (not present in definition of thing)' do
      thing = create_thing_with_overlay
      assert_equal('Test-Thing-With-Overlay', thing.name)
      assert_equal('Test Overlay', thing.name_overlay)
      assert_nil(thing.description) # no exception as it is handled by active_record
      assert_raise(NoMethodError) { thing.description_overlay }
    end

    test 'add simple_object in overlay (not present in definition of thing)' do
      thing = create_thing_with_simple_object
      assert_raise(NoMethodError) { thing.validity_period }
      assert_raise(NoMethodError) { thing.validity_period_overlay }
    end

    test 'add embedded in overlay (not present in definition of thing)' do
      thing = create_thing_with_embedded
      assert_raise(NoMethodError) { thing.embedded }
      assert_raise(NoMethodError) { thing.embedded_overlay }
    end

    test 'add linked in overlay (not present in definition of thing)' do
      image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild' })
      thing = create_thing_with_linked(image)
      assert_raise(NoMethodError) { thing.linked }
      assert_raise(NoMethodError) { thing.linked_overlay }
    end
  end
end
