# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require_relative '../../helpers/minitest_hook_helper'

module DataCycleCore
  class DataCycleApiV4Test < ActiveSupport::TestCase
    include DataCycleCore::MinitestHookHelper

    POSSIBLE_ENTITIES = [
      { '@type': 'Event', name: 'Test Event' },
      { '@type': 'POI', name: 'Test TouristAttraction' },
      { '@type': 'Tour', name: 'Test Trail' },
      { '@type': 'Organization', name: 'Test Organization' },
      { '@type': 'Person', family_name: 'Last', given_name: 'First' }
    ].freeze

    # helpers
    def create_content_in_external_system(type:, external_system: nil, user: nil)
      raise 'Invalid type' unless POSSIBLE_ENTITIES.pluck(:@type).include?(type)

      save_time = Time.zone.now

      user = @current_user if user.blank?
      external_system = @external_system if external_system.blank?

      thing = DataCycleCore::Thing.new(template_name: type)

      thing.created_at = save_time
      thing.updated_at = save_time
      thing.created_by = user.id
      thing.external_key = SecureRandom.uuid
      thing.external_source_id = external_system.id
      thing.save!(touch: false)

      data_hash = { 'name' => "Test #{type}" } unless type == 'Person'
      data_hash = { 'given_name' => 'First', 'family_name' => 'Last' } if type == 'Person'

      thing.set_data_hash(
        data_hash:,
        new_content: true,
        current_user: user,
        update_search_all: false,
        prevent_history: false,
        save_time:,
        version_name: nil,
        source: nil
      )
      thing
    end

    def api_strategy
      DataCycleCore::Generic::DataCycleApiV4::Webhook.new(@external_system, nil, nil, nil)
    end

    def api_strategy_minimal
      DataCycleCore::Generic::DataCycleApiV4::Webhook.new(@external_system_minimal, nil, nil, nil)
    end

    # A fixture set gets its own system: the shared one does not allow these templates, and adding
    # them there would widen what ~40 other tests are permitted to push.
    def push_external_system(identifier, allowed_templates)
      attributes = {
        'name' => "test-#{identifier}",
        'identifier' => identifier,
        'credentials' => nil,
        'deactivated' => false,
        'config' => { 'api_strategy' => 'DataCycleCore::Generic::DataCycleApiV4::Webhook' },
        'default_options' => { 'allowed_templates' => allowed_templates }
      }

      DataCycleCore::ExternalSystem.find_or_initialize_by(name: attributes['name']).tap do |system|
        system.attributes = attributes
        # bang: an unsaved system has no id, and the push would then write content with no source
        # rather than fail here
        system.save!
      end
    end

    def embedded_multi_template_external_system
      push_external_system('push_api_v4_embedded_multi', ['Embedded-Multiple-Templates-Entity-1', 'Embedded-Multiple-Templates-1'])
    end

    # As the controller does it, one per request.
    def embedded_multi_template_strategy
      DataCycleCore::Generic::DataCycleApiV4::Webhook.new(embedded_multi_template_external_system, nil, nil, nil)
    end

    # Nests an embedded inside an embedded, which is what the invalidation test below is about.
    def nested_embedded_external_system
      push_external_system('push_api_v4_nested_embedded', ['Strukturierter Artikel', 'Inhaltsblock', 'Action'])
    end

    def nested_embedded_strategy
      DataCycleCore::Generic::DataCycleApiV4::Webhook.new(nested_embedded_external_system, nil, nil, nil)
    end

    def collection_and_table_external_system
      push_external_system('push_api_v4_collection_and_table', ['Entity-With-Collection-And-Table', 'Embedded-With-Collection'])
    end

    def oembed_external_system
      push_external_system('push_api_v4_oembed', ['OEmbed'])
    end

    def push_to(external_system, data)
      DataCycleCore::Generic::DataCycleApiV4::Webhook.new(external_system, nil, nil, nil)
        .create(data, external_system, @current_user)
    end

    def push_collection_and_table(data)
      push_to(collection_and_table_external_system, { '@type' => 'Entity-With-Collection-And-Table' }.merge(data))
    end

    def push_oembed(data)
      push_to(oembed_external_system, { '@type' => 'OEmbed' }.merge(data))
    end

    before(:all) do
      # Must be a privileged user: this user performs all the create/update operations below.
      # Don't use User.first — it orders by the random UUID primary key, so once the test setup
      # started seeding a guest user (rank 0) it could resolve to the guest and forbid every create.
      @current_user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @not_allowed_user = DataCycleCore::User.create!(email: 'guest@example.com', password: SecureRandom.hex, role: DataCycleCore::Role.find_by(rank: 0))

      external_system_full =
        {
          'name' => 'test-push_api_v4',
          'identifier' => 'push_api_v4',
          'credentials' => nil,
          'deactivated' => false,
          'config' => {
            'api_strategy' => 'DataCycleCore::Generic::DataCycleApiV4::Webhook'
          },
          'default_options' => {
            'allowed_templates' => ['POI', 'Event', 'Tour', 'Organization', 'Person', 'Bild', 'Ergänzende Information'],
            'allowed_linked_templates' => ['Gastronomischer Betrieb', 'LocalBusiness', 'Örtlichkeit', 'Unterkunft'],
            'attribute_whitelist' => ['asset']
          }
        }
      @external_system = DataCycleCore::ExternalSystem.find_or_initialize_by(name: external_system_full['name'])
      @external_system.attributes = external_system_full
      @external_system.save

      external_system_minimal = {
        'name' => 'test-push_api_v4_minimal',
        'identifier' => 'push_api_v4_minimal',
        'credentials' => nil,
        'deactivated' => false,
        'config' => {
          'api_strategy' => 'DataCycleCore::Generic::DataCycleApiV4::Webhook'
        },
        'default_options' => {
          'allowed_templates' => ['POI', 'Ergänzende Information'],
          'allowed_linked_templates' => ['Event'],
          'attribute_whitelist' => ['asset']
        }
      }
      @external_system_minimal = DataCycleCore::ExternalSystem.find_or_initialize_by(name: external_system_minimal['name'])
      @external_system_minimal.attributes = external_system_minimal
      @external_system_minimal.save

      @content = {
        'person' => DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: { given_name: 'First', family_name: 'Last' }),
        'poi' => DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'TouristAttraction 1' }),
        'event' => DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: { name: 'Event 1' }),
        'organization' => DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: 'Organization 1' }),
        'bild' => DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'ImageObject 1' })
      }

      @content_external_system = POSSIBLE_ENTITIES.map do |entity|
        create_content_in_external_system(type: entity[:@type])
      end
    end

    test 'create items via data_cycle_api_v4 webhook with minimal data' do
      POSSIBLE_ENTITIES.each do |entity|
        entity_id = SecureRandom.uuid

        result = api_strategy.create(
          entity.transform_keys(&:to_s).merge('@id' => entity_id),
          @external_system,
          @current_user
        )

        assert result[:success]
        assert_predicate result.key?(:error), :blank?
        assert_predicate result.key?(:warning), :blank?

        assert result.key?(:meta)
        assert result[:meta].key?(:thing_id)

        assert result[:meta][:created].present? && result[:meta][:created].one?

        content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

        assert_equal entity_id, content.external_key
        assert_equal @external_system.id, content.external_source_id
        if entity[:@type] == 'Person'
          assert_equal entity[:given_name], content.given_name
          assert_equal entity[:family_name], content.family_name
        else
          assert_equal entity[:name], content.name
        end

        assert_equal @current_user.id, content.created_by
        assert_equal @current_user.id, content.updated_by
      end
    end

    test 'cannot create item via data_cycle_api_v4 webhook without data' do
      result = api_strategy.create({}, @external_system, @current_user)

      assert_not result[:success]
      assert result.key?(:error)
      assert_equal 'no data', result[:error]
    end

    test 'cannot create things via data_cycle_api_v4 webhook with templates that are not specifically allowed' do
      # main thing
      response = api_strategy_minimal.create(
        {
          '@type' => 'Tour',
          'name' => 'Test Trail'
        }, @external_system_minimal, @current_user
      )
      # linked thing
      response2 = api_strategy_minimal.create(
        {
          '@type' => 'POI',
          'name' => 'Test TouristAttraction',
          'image' => [{
            '@type' => 'Bild', '@id': 'test-id-bild', name: 'Test ImageObject'
          }]
        }, @external_system_minimal, @current_user
      )

      assert_not response[:success]
      assert_equal 'forbidden @type', response[:error].first[:message]
      assert_equal 'partial', response2[:success]
      assert_equal 'forbidden @type', response2[:error].first[:message]
    end

    test 'cannot create things with templates that are readonly' do
      response = api_strategy_minimal.create(
        {
          '@type' => 'Event', 'name' => 'Test Event'
        }, @external_system_minimal, @current_user
      )

      assert_not response[:success]
      assert_equal 'readonly @type: not allowed to create', response[:error].first[:message]
    end

    test 'data_cycle_api_v4 webhook: "@id" field is saved as external key' do
      external_key = 'some-external-key'
      response = api_strategy.create(
        {
          '@type' => 'Event',
          '@id' => external_key,
          'name' => 'dfdfd'
        }, @external_system, @current_user
      )

      assert response[:success]
      content = DataCycleCore::Thing.find_by(external_key:)

      assert_not content.blank?
    end

    test 'can create embedded elements via data_cycle_api_v4 webhook' do
      event = create_content_in_external_system(type: 'Event')
      response = api_strategy.create(
        {
          '@type' => 'Event',
          '@id' => event.id,
          'dc:additionalInformation' => [
            {
              '@type' => 'Ergänzende Information',
              'name' => 'Kurzbeschreibung',
              'description' => 'Text'
            },
            {
              '@type' => 'Ergänzende Information',
              'name' => 'Langbeschreibung',
              'description' => 'Text'
            }
          ]
        }, @external_system, @current_user
      )

      assert response[:success]
      assert_equal 'Ergänzende Information', response.dig(:meta, :created).first[:template]
      assert_equal ['dc:additionalInformation', 0], response.dig(:meta, :created).first[:path]
      assert_equal 'Ergänzende Information', response.dig(:meta, :created).second[:template]
      assert_equal ['dc:additionalInformation', 1], response.dig(:meta, :created).second[:path]
    end

    # The push reported in #51033. map_embedded_values leaves the slot nothing but each item's id,
    # so a multi-template slot has no template_name left to resolve and the whole push failed. The
    # validator-level tests cannot show this: they hand set_data_hash a payload the transformation
    # would have stripped, and dc:additionalInformation, the only embedded slot pushed elsewhere in
    # this file, allows a single template.
    test 'pushes a multi template embedded slot via data_cycle_api_v4 webhook' do
      external_system = embedded_multi_template_external_system

      result = embedded_multi_template_strategy.create(
        {
          '@type' => 'Embedded-Multiple-Templates-Entity-1',
          '@id' => 'multi-template-entity-1',
          'name' => 'Entity mit Modul',
          'embedded_creative_work' => [
            { '@type' => 'Embedded-Multiple-Templates-1', '@id' => 'multi-template-module-1', 'name' => 'Modul' }
          ]
        }, external_system, @current_user
      )

      assert result[:success], "push rejected: #{result[:error].inspect}"

      entity = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_equal ['Embedded-Multiple-Templates-1'], entity.embedded_creative_work.pluck(:template_name)
    end

    # #51423: an embedded content is rendered inline into the cached api output of its parents,
    # under their cache keys, while a push writes only the embedded row itself. Invalidating just
    # the pushed entity left the content block in between serving what its action held before, and
    # the caller reads back over the api right after the push, so this cannot wait for a job.
    test 'invalidates the embedded contents between a pushed entity and a changed child' do
      push_system = nested_embedded_external_system
      payload = lambda { |action_name|
        {
          '@type' => 'Strukturierter Artikel',
          '@id' => 'nested-entity',
          'name' => 'Nested Entity',
          'content_block' => [{
            '@type' => 'Inhaltsblock',
            '@id' => 'nested-block',
            'name' => 'Nested Block',
            'potential_action' => [{ '@type' => 'Action', '@id' => 'nested-action', 'name' => action_name }]
          }]
        }
      }

      result = nested_embedded_strategy.create(payload.call('Action'), push_system, @current_user)

      assert result[:success], "push rejected: #{result[:error].inspect}"

      block = DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).content_block.first
      invalidated_at = block.cache_valid_since

      result = nested_embedded_strategy.create(payload.call('Action geändert'), push_system, @current_user)

      assert result[:success], "push rejected: #{result[:error].inspect}"
      assert_operator block.reload.cache_valid_since, :>, invalidated_at
    end

    # #51373: JSON sends a native true where the edit form sends the string 'true', and only the
    # create path casts at all — so a pushed true was stored as false, both on the pushed thing and
    # on the things created alongside it. Updates were unaffected.
    test 'casts booleans pushed as JSON values via data_cycle_api_v4 webhook' do
      { true => true, false => false, 'true' => true, 'false' => false, 'TRUE' => true, 'False' => false }.each_with_index do |(pushed, expected), index|
        result = api_strategy.create({
          '@type' => 'Bild',
          '@id' => "boolean-image-#{index}",
          'name' => "Boolean Image #{index}",
          'mandatoryLicense' => pushed
        }, @external_system, @current_user)

        assert result[:success], "push rejected: #{result[:error].inspect}"
        assert_equal expected, DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).mandatory_license, "pushed #{pushed.inspect}"
      end

      result = api_strategy.create({
        '@type' => 'Event',
        '@id' => 'boolean-child-event',
        'name' => 'Boolean Child Event',
        'image' => [{
          '@id' => 'boolean-child-image',
          '@type' => 'Bild',
          'name' => 'Boolean Child Image',
          'mandatoryLicense' => true
        }]
      }, @external_system, @current_user)

      assert result[:success], "push rejected: #{result[:error].inspect}"
      assert DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).image.first.mandatory_license
    end

    # #51423: a format the boolean validator rejects used to be swallowed into false, so the push
    # looked like it had been ignored instead of reporting what was wrong with it
    test 'reports a boolean pushed in an unsupported format via data_cycle_api_v4 webhook' do
      [1, 'yes'].each_with_index do |pushed, index|
        result = api_strategy.create({
          '@type' => 'Bild',
          '@id' => "invalid-boolean-image-#{index}",
          'name' => "Invalid Boolean Image #{index}",
          'mandatoryLicense' => pushed
        }, @external_system, @current_user)

        assert_not result[:success], "pushed #{pushed.inspect}"
        assert result[:error].any? { |e| e[:message].try(:dig, 'de')&.key?(:mandatory_license) }, "pushed #{pushed.inspect}: #{result[:error].inspect}"
      end
    end

    test 'create event via data_cycle_api_v4 webhook and link to existing things' do
      result = api_strategy.create({
        '@type' => 'Event',
        '@id' => 'test-id-1',
        'name' => 'Test Event 1',
        'image' => [{
          '@id' => @content['bild'].id,
          '@type' => @content['bild'].template_name
        }],
        'organizer' => [{
          '@id' => @content['person'].id,
          '@type' => @content['person'].template_name
        }],
        'location' => [{
          '@id' => @content['poi'].id,
          '@type' => @content['poi'].template_name
        }]
      }, @external_system, @current_user)

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_equal @content['bild'].id, content.image.first.id
      assert_equal @content['person'].id, content.organizer.first.id
      assert_equal @content['poi'].id, content.content_location.first.id
    end

    test 'create poi via data_cycle_api_v4 webhook with geo info' do
      thing_data = {
        '@type' => 'POI',
        'name' => 'Test TouristAttraction',
        'geo' => {
          '@type' => 'GeoCoordinates',
          'latitude' => 14.1,
          'longitude' => 14.2
        }
      }

      result = api_strategy.create(thing_data, @external_system, @current_user)

      assert result[:success]

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_equal content.location.coordinates.first(2), [thing_data['geo']['longitude'], thing_data['geo']['latitude']]
    end

    test 'create poi via data_cycle_api_v4 webhook with geo info given as strings' do
      thing_data = {
        '@type' => 'POI',
        'name' => 'Test TouristAttraction',
        'geo' => {
          '@type' => 'GeoCoordinates',
          'latitude' => '47.79587651488799',
          'longitude' => '11.838692267683289'
        }
      }

      result = api_strategy.create(thing_data, @external_system, @current_user)

      assert result[:success]

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_equal [11.838692267683289, 47.79587651488799], content.location.coordinates.first(2)
    end

    test 'create poi via data_cycle_api_v4 webhook with zero geo info given as strings' do
      thing_data = {
        '@type' => 'POI',
        'name' => 'Test TouristAttraction',
        'geo' => {
          '@type' => 'GeoCoordinates',
          'latitude' => '0',
          'longitude' => '0'
        }
      }

      result = api_strategy.create(thing_data, @external_system, @current_user)

      assert result[:success]

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_nil content.location
    end

    test 'create poi via data_cycle_api_v4 webhook with address (+ contact info)' do
      thing_data = {
        '@type' => 'POI',
        'name' => 'Test TouristAttraction',
        'address' => {
          '@type' => 'PostalAddress',
          'url' => 'https://www.example.com',
          'email' => 'test@email.at',
          'telephone' => '+43 123456789',
          'name' => 'First Last',
          'streetAddress' => 'Teststraße 1',
          'addressCountry' => 'Wakanda'
        }
      }

      # Create the TouristAttraction
      result = api_strategy.create(thing_data, @external_system, @current_user)

      assert result[:success]

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_predicate content.address, :present?
      assert_equal content.address.to_h, {
        'street_address' => thing_data['address']['streetAddress'],
        'address_country' => thing_data['address']['addressCountry']
      }

      assert_predicate content.contact_info, :present?
      assert_equal({
        'url' => thing_data['address']['url'],
        'email' => thing_data['address']['email'],
        'telephone' => thing_data['address']['telephone'],
        'contact_name' => thing_data['address']['name']
      }, content.contact_info.to_h)
    end

    test 'create TouristAttraction via data_cycle_api_v4 webhook with opening times' do
      opening_specs1 = {
        '@type' => 'OpeningHoursSpecification',
        'dayOfWeek' => 'https://schema.org/Monday',
        'opens' => '08:00',
        'closes' => '18:00',
        'validFrom' => Time.zone.now.strftime('%Y-%m-%d'),
        'validThrough' => 1.year.from_now.strftime('%Y-%m-%d')
      }

      opening_specs2 = {
        '@type' => 'OpeningHoursSpecification',
        'dayOfWeek' => ['https://schema.org/Tuesday', 'https://schema.org/Wednesday'],
        'opens' => '07:00',
        'closes' => '13:00',
        'validFrom' => Time.zone.now.strftime('%Y-%m-%d'),
        'validThrough' => 2.years.from_now.strftime('%Y-%m-%d')
      }

      opening_specs1_raw = opening_specs1.deep_dup
      opening_specs2_raw = opening_specs2.deep_dup

      result = api_strategy.create({
        '@type' => 'POI',
        '@id' => 'test-id-1',
        'name' => 'Test TouristAttraction 1',
        'openingHoursSpecification' => [opening_specs1, opening_specs2]
      }, @external_system, @current_user)

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      created_schedules = content.opening_hours_specification

      ignore_keys = ['@id']
      raw_specs = [opening_specs1_raw, opening_specs2_raw]

      index = 0
      while index < created_schedules.length
        schedule = created_schedules[index]
        created_schedule = schedule.to_opening_hours_specification_schema_org&.first
        spec = raw_specs[index]

        assert(created_schedule.keys.all? do |key|
          if key == 'dayOfWeek'
            Array(created_schedule[key]).to_set == Array(spec[key]).to_set
          elsif ignore_keys.include?(key)
            true
          else
            created_schedule[key] == spec[key]
          end
        end)
        index += 1
      end
    end

    test 'errors when creating TouristAttraction via data_cycle_api_v4 webhook with wrong opening times' do
      # missing opens
      opening_specs1 = {
        '@type' => 'OpeningHoursSpecification',
        'dayOfWeek' => 'https://schema.org/Monday',
        'opens' => '08:00',
        'validFrom' => Time.zone.now.strftime('%Y-%m-%d'),
        'validThrough' => 1.year.from_now.strftime('%Y-%m-%d')
      }

      # validThrough before validFrom
      opening_specs2 = {
        '@type' => 'OpeningHoursSpecification',
        'dayOfWeek' => ['https://schema.org/Tuesday', 'https://schema.org/Wednesday'],
        'opens' => '07:00',
        'closes' => '13:00',
        'validFrom' => 20.days.from_now.strftime('%Y-%m-%d'),
        'validThrough' => 15.days.from_now.strftime('%Y-%m-%d')
      }

      # in the past
      opening_specs3 = {
        '@type' => 'OpeningHoursSpecification',
        'dayOfWeek' => ['https://schema.org/Tuesday', 'https://schema.org/Wednesday'],
        'opens' => '07:00',
        'closes' => '13:00',
        'validFrom' => 3.days.ago.strftime('%Y-%m-%d'),
        'validThrough' => 1.day.ago.strftime('%Y-%m-%d')
      }

      # invalid dayOfWeek
      opening_specs4 = {
        '@type' => 'OpeningHoursSpecification',
        'dayOfWeek' => ['https://schema.org/Tueday'],
        'opens' => '07:00',
        'closes' => '13:00',
        'validFrom' => Time.zone.now.strftime('%Y-%m-%d'),
        'validThrough' => 1.year.from_now.strftime('%Y-%m-%d')
      }

      result = api_strategy.create({
        '@type' => 'POI',
        '@id' => 'test-id-1',
        'name' => 'Test TouristAttraction 1',
        'openingHoursSpecification' => [opening_specs1, opening_specs2, opening_specs3, opening_specs4]
      }, @external_system, @current_user)

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      created_schedules = content.opening_hours_specification

      assert_empty created_schedules
      # find all errors with path ["opening_hours_specification", 0], one of them should be "Following keys are missing: closes"
      assert(result[:error].find { |e| e[:path] == ['opening_hours_specification', 0] && e[:message].include?('Following keys are missing: closes') })
      # find all errors with path ["opening_hours_specification", 1], one of them should be "The validFrom is after the validThrough"
      assert(result[:error].find { |e| e[:path] == ['opening_hours_specification', 1] && e[:message].include?('The validFrom is after the validThrough') })
      # find all errors with path ["opening_hours_specification", 2], one of them should be "The validThrough is in the past"
      assert(result[:error].find { |e| e[:path] == ['opening_hours_specification', 2] && e[:message].include?('The validThrough is in the past') })
      # find all errors with path ["opening_hours_specification", 3], one of them should be "There are no valid days in the week"
      assert(result[:error].find { |e| e[:path] == ['opening_hours_specification', 3] && e[:message].include?('There are no valid days in the week') })
    end

    test 'create event via data_cycle_api_v4 webhook and create new linked things in the same request' do
      result = api_strategy.create({
        '@type' => 'Event',
        '@id' => 'test-id-2',
        'name' => 'Test Event 2',
        'organizer' => [{
          '@id' => 'Person Linked 1',
          '@type' => 'Person',
          'given_name' => 'First',
          'family_name' => 'Last'
        }],
        'location' => [{
          '@id' => 'TouristAttraction Linked 1',
          '@type' => 'POI',
          'name' => 'TouristAttraction 1'
        }]
      }, @external_system, @current_user)

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_predicate content, :present?
      assert_predicate content.organizer.first, :present?
      assert_predicate content.content_location.first, :present?

      created_ids = result.dig(:meta, :created).pluck(:thing_id)

      assert created_ids.present? && created_ids.count == 3
      created_content = DataCycleCore::Thing.where(id: created_ids)

      assert created_content.present? && created_content.count == 3
    end

    test 'create event via data_cycle_api_v4 webhook with eventSchedule 1' do
      event_schedule = {
        '@type' => 'Schedule',
        'startDate' => '2024-06-01',
        'startTime' => '12:00',
        'endTime' => '14:00',
        'scheduleTimezone' => 'Europe/Vienna'
      }

      event_schedule_raw = event_schedule.deep_dup

      result = api_strategy.create({
        '@type' => 'Event',
        '@id' => 'test-id-1',
        'name' => 'Test Event 1',
        'eventSchedule' => [event_schedule]
      }, @external_system, @current_user)

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))
      created_schedule = content.event_schedule.first.to_schedule_schema_org

      assert(event_schedule_raw.keys.all? { |key| created_schedule[key] = event_schedule_raw[key] })
      assert_equal(ActiveSupport::Duration.build((Time.zone.parse(event_schedule['endTime']) - Time.zone.parse(event_schedule['startTime'])).seconds.to_i).iso8601, created_schedule['duration'])
      assert_equal '2024-06-01 14:00'.in_time_zone, content.event_schedule.first.schedule_object.end_time
    end

    test 'create event via data_cycle_api_v4 webhook with eventSchedule 2' do
      event_schedule = {
        '@type' => 'Schedule',
        'scheduleTimezone' => 'Europe/Vienna',
        'startDate' => '2023-07-16',
        'endDate' => '2023-08-20',
        'startTime' => '15:00',
        'endTime' => '16:00',
        'byDay' => 'https://schema.org/Sunday',
        'repeatFrequency' => 'P1M',
        'byMonthWeek' => 3
      }

      event_schedule_raw = event_schedule.deep_dup

      result = api_strategy.create({
        '@type' => 'Event',
        '@id' => 'test-id-1',
        'name' => 'Test Event 1',
        'eventSchedule' => [event_schedule]
      }, @external_system, @current_user)

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      created_schedule = content.event_schedule.first.to_schedule_schema_org

      assert(event_schedule_raw.keys.all? { |key| created_schedule[key] = event_schedule_raw[key] })
      assert_equal(ActiveSupport::Duration.build((Time.zone.parse(event_schedule['endTime']) - Time.zone.parse(event_schedule['startTime'])).seconds.to_i).iso8601, created_schedule['duration'])
    end

    test 'create event via data_cycle_api_v4 webhook with eventSchedule 3' do
      event_schedule = {
        '@type' => 'Schedule',
        'startDate' => '2024-06-01',
        'startTime' => '12:00',
        'scheduleTimezone' => 'Europe/Vienna',
        'endTime' => '14:00',
        'byDay' => ['https://schema.org/Tuesday', 'https://schema.org/Thursday'],
        'endDate' => '2024-12-31',
        'repeatFrequency' => 'P1W'
      }

      event_schedule_raw = event_schedule.deep_dup

      result = api_strategy.create({
        '@type' => 'Event',
        '@id' => 'test-id-1',
        'name' => 'Test Event 1',
        'eventSchedule' => [event_schedule]
      }, @external_system, @current_user)

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      created_schedule = content.event_schedule.first.to_schedule_schema_org

      assert(event_schedule_raw.keys.all? { |key| created_schedule[key] = event_schedule_raw[key] })
      assert_equal(ActiveSupport::Duration.build((Time.zone.parse(event_schedule['endTime']) - Time.zone.parse(event_schedule['startTime'])).seconds.to_i).iso8601, created_schedule['duration'])
    end

    test 'create thing via data_cycle_api_v4 webhook with classification' do
      tags = DataCycleCore::ClassificationAlias.for_tree('Tags').to_a
      tag_primary_classifications = tags.flat_map(&:primary_classification).pluck(:id)

      results = ['Event', 'POI'].map do |template|
        api_strategy.create({
          '@type' => template,
          'name' => 'Test Item',
          'dc:classification:tags' => tags.pluck(:id)
        }, @external_system, @current_user)
      end

      results.each do |result|
        content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

        assert_equal tag_primary_classifications.to_set, content.tags.pluck(:id).to_set
      end
    end

    test 'create thing via data_cycle_api_v4 webhook with universal classifications' do
      cc0_classification = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC0').first

      result = api_strategy.create({
        '@type' => 'Event',
        '@id' => 'test-id-1',
        'name' => 'Test Event 1',
        'dc:classification:universalClassifications' => [cc0_classification.id]
      }, @external_system, @current_user)

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_equal cc0_classification.primary_classification.id, content.universal_classifications.first.id
    end

    test 'create thing via data_cycle_api_v4 webhook with image and asset (remote_file_url)' do
      source_file = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb.jpeg')
      import_dir = Rails.root.join('private', 'import')
      FileUtils.mkdir_p(import_dir)
      tmp_file = Tempfile.new(['api_v4_image', '.jpeg'], import_dir)
      FileUtils.cp(source_file, tmp_file.path)

      result = api_strategy.create({
        '@type' => 'Event',
        '@id' => 'test-id-1',
        'name' => 'Test Event 1',
        'image' => [
          {
            '@id' => 'temp-id2',
            '@type' => 'Bild',
            'name' => 'Test-ImageObject 1',
            'asset' => {
              'remote_file_url' => tmp_file.path
            }
          }
        ]
      }, @external_system, @current_user)

      content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_predicate content.image, :present?
      assert_predicate content.image.first.asset, :present?
      assert_equal 'Test-ImageObject 1', content.image.first.name
      assert_equal 'temp-id2', content.image.first.external_key
    ensure
      tmp_file&.close!
    end

    # test 'create thing via data_cycle_api_v4 webhook with image and asset (base64_file_blob)' do
    #   image_id = SecureRandom.uuid
    #   image_name = 'Test ImageObject'
    #   ActiveStorage::Current.url_options = { host: 'localhost' }
    #   result = api_strategy.create({
    #     '@type' => 'POI',
    #     '@id' => 'test-id-1',
    #     'name' => 'Test TouristAttraction 1',
    #     'image' => [
    #       {
    #         '@id' => image_id,
    #         '@type' => 'Bild',
    #         'name' => image_name,
    #         'asset' => {
    #           'base64_file_blob' => 'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQMAAAD+wSzIAAAABlBMVEX///+/v7+jQ3Y5AAAADklEQVQI12P4AIX8EAgALgAD/aNpbtEAAAAASUVORK5CYII',
    #           'name' => 'image.png'
    #         }
    #       }
    #     ]
    #   }, @external_system, @current_user)

    #   content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

    #   assert content.image.present?
    #   assert content.image.first.asset.present?
    #   assert_equal image_name, content.image.first.name
    #   assert_equal image_id, content.image.first.external_key
    # end

    test 'cannot update/change template via data_cycle_api_v4 webhook' do
      templates = POSSIBLE_ENTITIES.pluck(:@type).reject { |template| template == 'Person' }
      things = @content_external_system.reject { |thing| thing.template_name == 'Person' }

      things.each do |thing|
        new_template = (templates - [thing.template_name]).sample
        result = api_strategy.create({
          '@id' => thing.external_key,
          '@type' => new_template,
          'name' => 'updated'
        }, @external_system, @current_user)

        assert_not result[:success]
        assert result.key?(:error)
        assert(result[:error].any? { |e| e[:message].include?('template mismatch') })
      end
    end

    test 'cannot update items with different external source via data_cycle_api_v4 webhook' do
      @content.each_value do |item|
        result = if item.template_name == 'Person'
                   api_strategy.create({
                     '@id' => item.id,
                     '@type' => item.template_name,
                     'given_name' => 'updated'
                   }, @external_system, @current_user)
                 else
                   api_strategy.create({
                     '@id' => item.id,
                     '@type' => item.template_name,
                     'name' => 'updated'
                   }, @external_system, @current_user)
                 end

        assert_not result[:success]
        assert_equal 'not allowed to update things from a different (external) system', result[:error].first[:message]
      end
    end

    test 'can update existing fields from thing via data_cycle_api_v4 webhook' do
      time_before_update = Time.zone.now
      things = @content_external_system

      things.each do |thing|
        result = if thing.template_name == 'Person'
                   api_strategy.create({
                     '@id' => thing.id,
                     '@type' => thing.template_name,
                     'given_name' => 'updated'
                   }, @external_system, @current_user)
                 else
                   api_strategy.create({
                     '@id' => thing.id,
                     '@type' => thing.template_name,
                     'name' => 'updated'
                   }, @external_system, @current_user)
                 end

        content = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

        assert result[:success]
        assert_predicate result.key?(:error), :blank?
        assert_predicate result.key?(:warning), :blank?
        assert_equal 'updated', content.given_name if thing.template_name == 'Person'
        assert_equal 'updated', content.name unless thing.template_name == 'Person'

        assert_operator content.updated_at, :>, time_before_update
        assert_equal @current_user.id, content.updated_by
      end
    end

    test 'can delete existing fields from thing via data_cycle_api_v4 webhook' do
      result = api_strategy.create({
        '@type' => 'POI',
        'name' => 'Test TouristAttraction',
        'address' => {
          '@type' => 'PostalAddress',
          'url' => 'https://www.example.com',
          'email' => 'email@example.org'
        },
        'image' => [@content['bild'].id]
      }, @external_system, @current_user)

      assert result[:success]

      new_email = 'https://www.example2.com'

      result2 = api_strategy.create({
        '@type' => 'POI',
        '@id' => result.dig(:meta, :thing_id),
        'address' => {
          '@type' => 'PostalAddress',
          'url' => new_email,
          'email' => nil
        },
        'image' => []
      }, @external_system, @current_user)

      assert result2[:success]
      assert result2.dig(:meta, :updated).size.positive? && result2.dig(:meta, :updated).first[:thing_id] == result2.dig(:meta, :thing_id)
      content = DataCycleCore::Thing.find(result2.dig(:meta, :thing_id))

      assert_empty content.image
      assert_equal new_email, content.contact_info.to_h['url']
      assert_predicate content.contact_info.to_h['email'], :blank?
    end

    test 'cannot update non-existent fields on the template via data_cycle_api_v4 webhook' do
      time_before_api_call = Time.zone.now

      things = @content_external_system

      things.each do |item|
        result = api_strategy.create({
          '@id' => item.id,
          '@type' => item.template_name,
          'doesnotexist' => 'updated'
        }, @external_system, @current_user)

        thing = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

        assert result[:success]
        assert_predicate result.key?(:error), :blank?
        assert_empty result.dig(:meta, :created)
        assert_empty result.dig(:meta, :updated)
        assert_predicate result[:warnings].size, :positive?
        assert(result[:warnings].find { |w| w[:message].include?('Some keys were ignored') && w[:message].include?('doesnotexist') })
        assert_operator thing.updated_at, :<, time_before_api_call
      end
    end

    test 'cannot add/modify virtual or computed fields via data_cycle_api_v4 webhook' do
      event = create_content_in_external_system(type: 'Event')

      result = api_strategy.create({
        '@id' => event.id,
        '@type' => event.template_name,
        'copyrightNoticeComputed' => 'updated',
        'virtualDescription' => 'updated'
      }, @external_system, @current_user)

      assert result[:success]
      assert_predicate result.key?(:error), :blank?
      assert_empty result.dig(:meta, :created)
      assert_empty result.dig(:meta, :updated)
      assert_predicate result[:warnings].size, :positive?
      assert(result[:warnings].find do |w|
               w[:message].include?('Some keys were ignored') && w[:message].include?('copyrightNoticeComputed') && w[:message].include?('virtualDescription')
             end)
    end

    test 'can update linked fields via data_cycle_api_v4 webhook' do
      event = create_content_in_external_system(type: 'Event')
      poi = create_content_in_external_system(type: 'POI')
      result = api_strategy.create({
        '@id' => event.id,
        '@type' => event.template_name,
        'organizer' => [
          @content['person'].id # short version for internal id
        ],
        'location' => [
          {
            '@id' => poi.id,
            '@type' => poi.template_name
          }
        ],
        'image' => [
          {
            '@type' => @content['bild'].template_name,
            '@id' => @content['bild'].id
          }
        ]
      }, @external_system, @current_user)

      assert result[:success]
      assert_predicate result.key?(:error), :blank?
      assert_predicate result.key?(:warning), :blank?

      thing = DataCycleCore::Thing.find(result.dig(:meta, :thing_id))

      assert_empty result.dig(:meta, :created)
      assert result.dig(:meta, :updated).size == 1 && result.dig(:meta, :updated).first[:thing_id] == event.id
      assert_equal thing.organizer.first.id, @content['person'].id
      assert_equal thing.content_location.first.id, poi.id
      assert thing.image.first.id = @content['bild'].id

      # check if we can update the new fields
      result2 = api_strategy.create({
        '@id' => event.id,
        '@type' => event.template_name,
        'organizer' => nil, # remove it
        'location' => [
          @content['poi'].id
        ], # change
        'image' => [
          {
            '@type' => @content['bild'].template_name,
            '@id' => @content['bild'].id
          },
          {
            '@type' => 'Bild',
            '@id' => SecureRandom.uuid,
            'name' => 'Test ImageObject'
          }
        ] # add a second image that will be newly created
      }, @external_system, @current_user)

      assert result2[:success]
      assert_predicate result2.key?(:error), :blank?
      assert_predicate result2.key?(:warning), :blank?

      thing = DataCycleCore::Thing.find(result2.dig(:meta, :thing_id)) # update the thing

      assert_equal 1, result2.dig(:meta, :created).size
      assert result2.dig(:meta, :updated).size == 1 && result2.dig(:meta, :updated).first[:thing_id] == event.id
      assert_predicate thing.organizer, :blank?
      assert_equal thing.content_location.first.id, @content['poi'].id
      assert_equal 2, thing.image.size
    end

    test 'can delete things via data_cycle_api_v4 webhook' do
      poi = create_content_in_external_system(type: 'POI')

      result = api_strategy.delete({
        '@id' => poi.id
      }, @external_system, @current_user)

      assert result[:success]
      assert_equal result.dig(:meta, :thing_id), poi.id
      assert_predicate DataCycleCore::Thing.find_by(id: poi.id), :blank?
    end

    test 'cannot delete things that are not from the defined external system via data_cycle_api_v4 webhook' do
      time_before_api_call = Time.zone.now
      @content.each_value do |item|
        result = api_strategy.delete({
          '@id' => item.id
        }, @external_system, @current_user)

        assert_not result[:success]
        assert DataCycleCore::Thing.find_by(id: item.id)
        assert_operator DataCycleCore::Thing.find_by(id: item.id).updated_at, :<, time_before_api_call
      end
    end

    test 'cannot delete embedded things directly via data_cycle_api_v4 webhook' do
      event = create_content_in_external_system(type: 'Event')
      response = api_strategy.create(
        {
          '@type' => 'Event',
          '@id' => event.id,
          'dc:additionalInformation' => [
            {
              '@type' => 'Ergänzende Information',
              'name' => 'Kurzbeschreibung',
              'description' => 'Text'
            }
          ]
        }, @external_system, @current_user
      )

      assert response[:success]

      response_delete = api_strategy.delete({
        '@id' => response.dig(:meta, :created).first[:thing_id]
      }, @external_system, @current_user)

      assert_not response_delete[:success]
      assert_equal :forbidden, response_delete[:status]
    end

    test 'Embedded thing will be deleted when the main thing is deleted via data_cycle_api_v4 webhook' do
      event = create_content_in_external_system(type: 'Event')
      response = api_strategy.create(
        {
          '@type' => 'Event',
          '@id' => event.id,
          'dc:additionalInformation' => [
            {
              '@type' => 'Ergänzende Information',
              'name' => 'Kurzbeschreibung',
              'description' => 'Text'
            }
          ]
        }, @external_system, @current_user
      )

      assert response[:success]
      embedded_id = response.dig(:meta, :created).first[:thing_id]
      response_delete = api_strategy.delete({
        '@id' => response.dig(:meta, :thing_id)
      }, @external_system, @current_user)

      assert response_delete[:success]
      assert_predicate DataCycleCore::Thing.find_by(id: embedded_id), :blank?
    end

    test 'erroneous data is handled correctly' do
      result = api_strategy.create({
        '@type' => 'POI',
        'name' => '123',
        'doesnotexist' => 'updated',
        'address' => {
          '@type' => 'PostalAddress',
          'url' => 123,
          'email' => 123
        },
        'image' => [
          {
            '@type' => @content['bild'].template_name,
            '@id' => @content['bild'].id
          },
          {
            '@type' => 'Bild',
            '@id' => SecureRandom.uuid,
            'name' => 'Test ImageObject'
          }
        ]
      }, @external_system, @current_user)

      assert_not result[:success]
      assert_predicate result[:error].size, :positive?

      result2 = api_strategy.create({
        '@type' => 1234,
        'name' => 'Test TouristAttraction 1',
        'image' => 123
      }, @external_system, @current_user)

      assert_not result2[:success]
      assert_predicate result2[:error].size, :positive?

      result3 = api_strategy.create({
        '@type' => ['POI'],
        'name' => 'Test TouristAttraction 1'
      }, @external_system, @current_user)

      assert_not result3[:success]
      assert_predicate result3[:error].size, :positive?

      result4 = api_strategy.create({
        '@type' => { 'POI' => 'POI' },
        'name' => 'Test TouristAttraction 1'
      }, @external_system, @current_user)

      assert_not result4[:success]
      assert_predicate result4[:error].size, :positive?
    end

    test 'validates if user can edit content' do
      event = create_content_in_external_system(type: 'Event')
      result = api_strategy.create({
        '@id' => event.id,
        '@type' => event.template_name,
        'name' => 'updated'
      }, @external_system, @not_allowed_user)

      assert_not result[:success]
    end

    # TODO: fix for vtg and possible other systems: admins cannot delete imported things (same comment in webhook)
    test 'validates if user can delete content' do
      event = create_content_in_external_system(type: 'Event')
      result = api_strategy.delete({
        '@id' => event.id
      }, @external_system, @not_allowed_user)

      assert_not result[:success]
    end

    test 'validates if user can create content' do
      result = api_strategy.create({
        '@type' => 'POI',
        'name' => 'Test TouristAttraction 1'
      }, @external_system, @not_allowed_user)

      assert_not result[:success]
    end

    test 'update delegates to create via data_cycle_api_v4 webhook' do
      poi = create_content_in_external_system(type: 'POI')

      result = api_strategy.update({
        '@type' => 'POI',
        '@id' => poi.id,
        'name' => 'Updated via update'
      }, @external_system, @current_user)

      assert result[:success]
      assert_equal 'Updated via update', DataCycleCore::Thing.find(poi.id).name
    end

    test 'delete without data returns no data via data_cycle_api_v4 webhook' do
      result = api_strategy.delete({}, @external_system, @current_user)

      assert_not result[:success]
      assert_equal 'no data', result[:error]
    end

    test 'delete without @id reports missing @id via data_cycle_api_v4 webhook' do
      result = api_strategy.delete({ '@type' => 'POI' }, @external_system, @current_user)

      assert_not result[:success]
      assert(result[:error].any? { |e| e[:message] == 'missing @id' })
    end

    test 'delete of an unknown @id reports not found via data_cycle_api_v4 webhook' do
      result = api_strategy.delete({ '@id' => SecureRandom.uuid }, @external_system, @current_user)

      assert_not result[:success]
      assert_equal :not_found, result[:status]
    end

    test 'referencing an unknown @id on update reports not found via data_cycle_api_v4 webhook' do
      result = api_strategy.create({
        '@type' => 'POI',
        '@id' => SecureRandom.uuid
      }, @external_system, @current_user)

      assert_not result[:success]
      assert(result[:error].any? { |e| e[:message].to_s.include?('not found') })
    end

    test 'create with an unknown @type is rejected via data_cycle_api_v4 webhook' do
      result = api_strategy.create({
        '@type' => 'ThisTemplateDoesNotExist',
        'name' => 'irrelevant'
      }, @external_system, @current_user)

      assert_not result[:success]
      assert_predicate result[:error], :present?
    end

    test 'demote without data returns no data via data_cycle_api_v4 webhook' do
      result = api_strategy.demote({}, @external_system, @current_user)

      assert_not result[:success]
      assert_equal 'no data', result[:error]
    end

    test 'demote without ids reports missing ids via data_cycle_api_v4 webhook' do
      result = api_strategy.demote({ 'ids' => [] }, @external_system, @current_user)

      assert_not result[:success]
      assert_equal :bad_request, result[:status]
    end

    test 'demote reports ids that cannot be found via data_cycle_api_v4 webhook' do
      result = api_strategy.demote({ 'ids' => [SecureRandom.uuid] }, @external_system, @current_user)

      assert_not result[:success]
      assert(result[:errors].any? { |e| e[:message].to_s.include?('not found') })
    end

    test 'demote detaches a thing from its primary external system via data_cycle_api_v4 webhook' do
      poi = create_content_in_external_system(type: 'POI')

      result = api_strategy.demote({ 'ids' => [poi.external_key] }, @external_system, @current_user)

      assert result[:success]
      poi.reload

      assert_nil poi.external_source_id
    end

    test 'cannot demote content from a different external system via data_cycle_api_v4 webhook' do
      result = api_strategy.demote({ 'ids' => [@content['poi'].id] }, @external_system, @current_user)

      assert_not result[:success]
    end

    test 'demote validates user permissions via data_cycle_api_v4 webhook' do
      poi = create_content_in_external_system(type: 'POI')

      result = api_strategy.demote({ 'ids' => [poi.external_key] }, @external_system, @not_allowed_user)

      assert_not result[:success]
    end

    test 'cannot create an embedded template directly via data_cycle_api_v4 webhook' do
      result = api_strategy.create({
        '@type' => 'Ergänzende Information',
        'name' => 'Kurzbeschreibung'
      }, @external_system, @current_user)

      assert_not result[:success]
      assert(result[:error].any? { |e| e[:message].to_s.include?('embedded') })
    end

    test 'cannot delete content whose template is not allowed via data_cycle_api_v4 webhook' do
      # Event is not in the minimal external system's allowed_templates
      event = create_content_in_external_system(type: 'Event', external_system: @external_system_minimal)

      result = api_strategy_minimal.delete({ '@id' => event.id }, @external_system_minimal, @current_user)

      assert_not result[:success]
      assert_equal :forbidden, result[:status]
    end

    test 'applies default values on create via data_cycle_api_v4 webhook' do
      external_system_defaults = DataCycleCore::ExternalSystem.find_or_initialize_by(name: 'test-push_api_v4_defaults')
      external_system_defaults.attributes = {
        'identifier' => 'push_api_v4_defaults',
        'credentials' => nil,
        'deactivated' => false,
        'config' => { 'api_strategy' => 'DataCycleCore::Generic::DataCycleApiV4::Webhook' },
        'default_options' => {
          'allowed_templates' => ['POI'],
          'default_values' => { 'name' => 'Default Name', 'nonexistent_property' => 'ignored' }
        }
      }
      external_system_defaults.save
      strategy = DataCycleCore::Generic::DataCycleApiV4::Webhook.new(external_system_defaults, nil, nil, nil)

      result = strategy.create({
        '@type' => 'POI',
        '@id' => 'defaults-1',
        'description' => 'only a description, no name'
      }, external_system_defaults, @current_user)

      assert result[:success]
      assert_equal 'Default Name', DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).name
    end

    test 'referencing an unknown linked @id only warns via data_cycle_api_v4 webhook' do
      result = api_strategy.create({
        '@type' => 'Event',
        '@id' => SecureRandom.uuid,
        'name' => 'Event with dangling image',
        'image' => [
          { '@type' => 'Bild', '@id' => SecureRandom.uuid }
        ]
      }, @external_system, @current_user)

      assert result[:success]
      assert_predicate result[:warnings], :present?
    end

    test 'DataCycleApiV4 Functions and Transformations helpers' do
      assert_equal({ 'a' => 'b', 'c' => { 'd' => 'e' } },
                   DataCycleCore::Generic::DataCycleApiV4::Functions.strip_all({ 'a' => ' b ', 'c' => { 'd' => ' e ' } }))
      assert_equal({ 'foo_bar' => 1 },
                   DataCycleCore::Generic::DataCycleApiV4::Functions.underscore_keys({ 'FooBar' => 1 }))
      assert_equal({ 'id' => '1', 'name' => 'y' },
                   DataCycleCore::Generic::DataCycleApiV4::Transformations.transformation.call({ '@id' => '1', '@type' => 'X', 'name' => ' y ' }))
    end

    test 'map_timeseries_values handles valid and invalid timeseries payloads' do
      template = DataCycleCore::Thing.new(template_name: 'TemplateConversionSource')
      key = template.timeseries_property_names.first

      assert_not_nil key

      # valid: hash ({x, y}) and array ([timestamp, value]) entries
      valid = {
        'dc_path' => [], 'dc_errors' => [], 'dc_warnings' => [],
        key => { '@type' => 'dc:timeseries', 'dc:values' => [{ 'x' => '2024-01-01', 'y' => 1 }, ['2024-01-02', 2]] }
      }
      result = DataCycleCore::Generic::DataCycleApiV4::TransformationFunctions.map_timeseries_values(valid, template)

      assert_equal([{ 'timestamp' => '2024-01-01', 'value' => 1 }, { 'timestamp' => '2024-01-02', 'value' => 2 }], result[key])
      assert_empty result['dc_errors']

      # invalid: value is not a hash
      not_a_hash = { 'dc_path' => [], 'dc_errors' => [], 'dc_warnings' => [], key => 'not-a-hash' }
      result = DataCycleCore::Generic::DataCycleApiV4::TransformationFunctions.map_timeseries_values(not_a_hash, template)

      assert(result['dc_errors'].any? { |e| e[:message].to_s.include?('has to be a hash') })

      # invalid: wrong @type
      wrong_type = { 'dc_path' => [], 'dc_errors' => [], 'dc_warnings' => [], key => { '@type' => 'wrong', 'dc:values' => [] } }
      result = DataCycleCore::Generic::DataCycleApiV4::TransformationFunctions.map_timeseries_values(wrong_type, template)

      assert(result['dc_errors'].any? { |e| e[:message].to_s.include?('dc:timeseries') })

      # invalid: malformed value entries produce warnings
      bad_values = { 'dc_path' => [], 'dc_errors' => [], 'dc_warnings' => [], key => { '@type' => 'dc:timeseries', 'dc:values' => ['bad', [1]] } }
      result = DataCycleCore::Generic::DataCycleApiV4::TransformationFunctions.map_timeseries_values(bad_values, template)

      assert_predicate result['dc_warnings'], :present?
    end

    test 'errors when opening hours weekday is outside the validity range via data_cycle_api_v4 webhook' do
      monday = Time.zone.today.next_occurring(:monday)

      result = api_strategy.create({
        '@type' => 'POI',
        '@id' => 'opening-range-1',
        'name' => 'Test opening hours range',
        'openingHoursSpecification' => [{
          '@type' => 'OpeningHoursSpecification',
          'dayOfWeek' => 'https://schema.org/Sunday',
          'opens' => '08:00',
          'closes' => '18:00',
          'validFrom' => monday.strftime('%Y-%m-%d'),
          'validThrough' => (monday + 1).strftime('%Y-%m-%d')
        }]
      }, @external_system, @current_user)

      messages = (Array.wrap(result[:error]) + Array.wrap(result[:warnings])).map { |e| e[:message].to_s }.join(' ')

      assert_includes messages, 'week days are not in the range'
    end

    # collection and table are two of the property types the push api key filter used to drop: a
    # required property of either type was both demanded by the template validation and discarded
    # by the push, so the content could not be created at all.
    test 'pushes collections as uuids via data_cycle_api_v4 webhook' do
      stored_filter = DataCycleCore::StoredFilter.create!(name: 'push suche 1', user: @current_user, language: ['de'])
      watch_list = DataCycleCore::WatchList.create!(full_path: 'push Inhaltssammlung 1', user: @current_user)

      result = push_collection_and_table({
        '@id' => SecureRandom.uuid,
        'name' => 'Entity with collections',
        'dcls:collections' => [stored_filter.id, watch_list.id]
      })

      assert result[:success]
      assert_predicate result[:warnings], :blank?
      assert_equal [stored_filter.id, watch_list.id], DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).collections.pluck(:id)
    end

    test 'pushes collections as api reference objects via data_cycle_api_v4 webhook' do
      stored_filter = DataCycleCore::StoredFilter.create!(name: 'push suche 2', user: @current_user, language: ['de'])
      watch_list = DataCycleCore::WatchList.create!(full_path: 'push Inhaltssammlung 2', user: @current_user)

      result = push_collection_and_table({
        '@id' => SecureRandom.uuid,
        'name' => 'Entity with collection references',
        'dcls:collections' => [
          { '@id' => stored_filter.id, '@type' => ['CreativeWork', 'Collection', 'dcls:StoredFilter'] },
          { '@id' => watch_list.id, '@type' => ['CreativeWork', 'Collection', 'dcls:WatchList'] }
        ]
      })

      assert result[:success]
      assert_predicate result[:warnings], :blank?
      assert_equal [stored_filter.id, watch_list.id], DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).collections.pluck(:id)
    end

    test 'clears collections via data_cycle_api_v4 webhook' do
      stored_filter = DataCycleCore::StoredFilter.create!(name: 'push suche 3', user: @current_user, language: ['de'])
      external_key = SecureRandom.uuid

      push_collection_and_table({
        '@id' => external_key,
        'name' => 'Entity with collections to clear',
        'dcls:collections' => [stored_filter.id]
      })

      result = push_collection_and_table({ '@id' => external_key, 'dcls:collections' => [] })

      assert result[:success]
      assert_empty DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).collections
    end

    test 'warns about an unknown collection @id via data_cycle_api_v4 webhook' do
      stored_filter = DataCycleCore::StoredFilter.create!(name: 'push suche 4', user: @current_user, language: ['de'])
      unknown_id = SecureRandom.uuid

      result = push_collection_and_table({
        '@id' => SecureRandom.uuid,
        'name' => 'Entity with dangling collection',
        'dcls:collections' => [stored_filter.id, unknown_id]
      })

      assert result[:success]
      assert(result[:warnings].any? { |w| w[:message].to_s.include?(unknown_id) })
      assert_equal [stored_filter.id], DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).collections.pluck(:id)
    end

    test 'pushes collections on an embedded module via data_cycle_api_v4 webhook' do
      watch_list = DataCycleCore::WatchList.create!(full_path: 'push Inhaltssammlung 5', user: @current_user)

      result = push_collection_and_table({
        '@id' => SecureRandom.uuid,
        'name' => 'Entity with an embedded module',
        'embeddedModule' => [{
          '@type' => 'Embedded-With-Collection',
          'name' => 'Module with a collection',
          'dcls:collections' => [watch_list.id]
        }]
      })

      assert result[:success]
      assert_predicate result[:warnings], :blank?
      assert_equal [watch_list.id], DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).embedded_module.first.collections.pluck(:id)
    end

    test 'pushes table data via data_cycle_api_v4 webhook' do
      table_data = [['Bergbahn', 'Preis'], ['Spieljochbahn', '25 EUR']]

      result = push_collection_and_table({
        '@id' => SecureRandom.uuid,
        'name' => 'Entity with a table',
        'tableData' => table_data
      })

      assert result[:success]
      assert_predicate result[:warnings], :blank?
      assert_equal table_data, DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).table_data
    end

    test 'pushes an oembed url via data_cycle_api_v4 webhook' do
      with_test_oembed_provider do
        external_key = SecureRandom.uuid

        result = push_oembed({ '@id' => external_key, 'name' => 'Entity with an oembed url', 'url' => TEST_OEMBED_URL })

        assert result[:success]
        assert_predicate result[:warnings], :blank?
        assert_equal TEST_OEMBED_URL, DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).url

        updated_url = "#{TEST_OEMBED_PROVIDER_URL}/watch?v=2"
        result = push_oembed({ '@id' => external_key, 'url' => updated_url })

        assert result[:success]
        assert_equal updated_url, DataCycleCore::Thing.find(result.dig(:meta, :thing_id)).url
      end
    end

    test 'reports an oembed url no provider serves via data_cycle_api_v4 webhook' do
      with_test_oembed_provider do
        unsupported_url = 'https://unsupported.test/watch?v=1'

        result = push_oembed({
          '@id' => SecureRandom.uuid,
          'name' => 'Entity with an unsupported oembed url',
          'url' => unsupported_url
        })

        assert_not result[:success]
        assert(Array.wrap(result[:error]).any? { |e| e[:message].to_s.include?(unsupported_url) })
      end
    end

    test 'reports an inverse linked property as unwriteable via data_cycle_api_v4 webhook' do
      organization = create_content_in_external_system(type: 'Organization')
      inverse_key = organization.inverse_linked_property_names.first

      assert_not_nil inverse_key

      result = api_strategy.create({
        '@id' => organization.id,
        '@type' => organization.template_name,
        organization.api_name_for(inverse_key) => [@content['person'].id]
      }, @external_system, @current_user)

      assert result[:success]
      assert(result[:warnings].find { |w| w[:message].include?('Some keys were ignored') && w[:message].include?('unwriteable property') })
    end

    # Fault-injection tests for the defensive error/rescue branches. These paths only run
    # when an underlying operation fails unexpectedly, so we simulate that failure with
    # Minitest's built-in stub (no mocking library) instead of contriving unreachable inputs.
    test 'reports an error when destroying content returns a non-destroyed record via data_cycle_api_v4 webhook' do
      poi = create_content_in_external_system(type: 'POI')

      # destroy_content returns the (still-persisted) record -> result.destroyed? is false
      poi.stub(:destroy_content, poi) do
        DataCycleCore::Thing.stub(:first_by_external_key_or_id, poi) do
          result = api_strategy.delete({ '@id' => poi.id }, @external_system, @current_user)

          assert_not result[:success]
          assert(Array.wrap(result[:error]).any? { |e| e[:message].to_s.include?('error deleting content') })
        end
      end
    end

    test 'rescues unexpected errors while destroying content via data_cycle_api_v4 webhook' do
      poi = create_content_in_external_system(type: 'POI')

      poi.stub(:destroy_content, ->(*, **) { raise StandardError, 'boom' }) do
        DataCycleCore::Thing.stub(:first_by_external_key_or_id, poi) do
          result = api_strategy.delete({ '@id' => poi.id }, @external_system, @current_user)

          assert_not result[:success]
          assert(Array.wrap(result[:error]).any? { |e| e[:message].to_s.include?('error deleting content') })
        end
      end
    end

    test 'reports an error when demote fails to detach the primary external system via data_cycle_api_v4 webhook' do
      poi = create_content_in_external_system(type: 'POI')

      # sync is a no-op -> external_source_id/external_key stay set -> demote is reported as failed
      poi.stub(:external_source_to_external_system_syncs, nil) do
        DataCycleCore::Thing.stub(:first_by_external_key_or_id, poi) do
          result = api_strategy.demote({ 'ids' => [poi.external_key] }, @external_system, @current_user)

          assert_not result[:success]
          assert(Array.wrap(result[:errors]).any? { |e| e[:message].to_s.include?('error demoting content') })
        end
      end
    end

    test 'rescues unexpected errors while demoting content via data_cycle_api_v4 webhook' do
      poi = create_content_in_external_system(type: 'POI')

      poi.stub(:external_source_to_external_system_syncs, ->(*, **) { raise StandardError, 'boom' }) do
        DataCycleCore::Thing.stub(:first_by_external_key_or_id, poi) do
          result = api_strategy.demote({ 'ids' => [poi.external_key] }, @external_system, @current_user)

          assert_not result[:success]
          assert(Array.wrap(result[:errors]).any? { |e| e[:message].to_s.include?('error demoting content') })
        end
      end
    end

    test 'rescues RecordInvalid raised during transformations via data_cycle_api_v4 webhook' do
      strategy = api_strategy
      raising_pipeline = ->(_base_data) { raise ActiveRecord::RecordInvalid }

      strategy.stub(:transformations, ->(*, **) { raising_pipeline }) do
        result = strategy.create({ '@type' => 'POI', '@id' => SecureRandom.uuid, 'name' => 'Test' }, @external_system, @current_user)

        assert_not result[:success]
        assert_predicate result[:error], :present?
      end
    end

    test 'reports no data when transformations yield an empty hash via data_cycle_api_v4 webhook' do
      strategy = api_strategy
      empty_pipeline = ->(_base_data) { {} }

      strategy.stub(:transformations, ->(*, **) { empty_pipeline }) do
        result = strategy.create({ '@type' => 'POI', '@id' => SecureRandom.uuid, 'name' => 'Test' }, @external_system, @current_user)

        assert_not result[:success]
        assert(Array.wrap(result[:error]).any? { |e| e[:message].to_s.include?('no data after transformations') })
      end
    end
  end
end
