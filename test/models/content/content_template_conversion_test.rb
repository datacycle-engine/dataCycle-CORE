# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    # [#44548, #49217] In-place type conversion during import (Content::Extensions::TemplateConversion),
    # e.g. POI -> Lift, POI -> Gastronomischer Betrieb.
    #
    # Acceptance criteria covered:
    #   AK1 conversion only via import
    #   AK2 in-place: same GUID, no new record
    #   AK3 feasibility check beforehand
    #   AK4 attribute mapping via the regular import transformation
    #   AK5 faulty change -> content left untouched + error logged
    #   Detail 1 everything except global/local is removed
    #   Detail 2 a template change triggers an Appsignal instrumentation
    #   Detail 3 the Thing itself exposes can_become? and obsolete_property_names_for, and cleans up after a template change
    #
    # NOTE: template_name is the STI inheritance column, so after an in-place conversion a reference
    # held from before the change is still the old subclass (e.g. Thing::Poi) while the row is now the
    # new type. Such a reference cannot be reload-ed (ActiveRecord::SubclassNotFound); re-fetch it via
    # DataCycleCore::Thing.find(id) to get the new STI class.
    #
    # The underlying STI casting primitive (becomes!/TemplateModels) is covered by content_template_models_test.rb.
    class ContentTemplateConversionTest < DataCycleCore::TestCases::ActiveSupportTestCase
      include DataCycleCore::Generic::Common::ImportFunctionsDataHelper

      before(:all) do
        @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
        @lift_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Lift')
        @utility_object = DataCycleCore::Generic::ImportObject.new(
          external_source: @external_system,
          import: {
            import_strategy: 'DataCycleCore::Generic::Common::ImportContents',
            source_type: 'contents'
          }
        )
      end

      test 'global properties are preserved, and required source attributes are not cleared (Detail 1)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-detail1', external_source_id: @external_system.id })

        assert_includes thing.preserved_property_names, 'tags', 'global classification should be preserved'
        assert_includes thing.preserved_property_names, 'output_channel', 'global classification should be preserved'
        assert_not_includes thing.obsolete_property_names_for(@lift_template), 'tags', 'global classification should be preserved'
        assert_not_includes thing.obsolete_property_names_for(@lift_template), 'output_channel', 'global classification should be preserved'

        assert_not_includes thing.obsolete_property_names_for(@lift_template), 'name', 'required source attribute should not be cleared'
      end

      test 'local properties are preserved across an in-place conversion (Detail 1)' do
        target_template = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionTarget')
        source = create_content('TemplateConversionSource', { name: 'Local Source', local_note: 'keep me', removable_note: 'drop me', mandatory_note: 'required value', external_key: 'tc-local', external_source_id: @external_system.id })

        assert_equal 'keep me', source.local_note
        assert_equal 'drop me', source.removable_note

        create_or_update_content(
          utility_object: @utility_object,
          template: target_template,
          data: { 'external_key' => 'tc-local', 'name' => 'Local Source' }
        )
        # the in-place conversion changed the STI type, so re-fetch instead of reloading the stale reference
        source = DataCycleCore::Thing.find(source.id)

        assert_equal 'TemplateConversionTarget', source.template_name
        assert_equal 'keep me', source.local_note, 'local property value must survive the conversion'
        assert_nil source.try(:removable_note), 'non-global/local property must be removed'
      end

      test 'obsolete attributes of every storage type are removed, including timeseries and orphaned required attributes (Detail 1 + QA)' do
        target_template = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionTarget')
        source = create_content('TemplateConversionSource', {
          name: 'All Types', external_key: 'tc-types', external_source_id: @external_system.id,
          local_note: 'keep me', removable_note: 'drop me', mandatory_note: 'drop me too',
          table_data: [['a', 'b'], ['c', 'd']], series: [{ 'timestamp' => Time.zone.now, 'value' => 1 }],
          geo_area: 'POINT (11.0 47.0)'
        })

        assert_equal 'drop me', source.removable_note
        assert_equal 'drop me too', source.mandatory_note
        assert_equal 1, DataCycleCore::Timeseries.where(thing_id: source.id, property: 'series').count, 'timeseries data was set'
        assert_equal 1, source.geometries.where(relation: 'geo_area').count, 'geographic data was set'

        create_or_update_content(
          utility_object: @utility_object,
          template: target_template,
          data: { 'external_key' => 'tc-types', 'name' => 'All Types' }
        )
        source = DataCycleCore::Thing.find(source.id)

        assert_equal 'TemplateConversionTarget', source.template_name
        assert_equal 'keep me', source.local_note, 'local attribute is preserved'

        metadata = source.read_attribute(:metadata) || {}

        assert_predicate metadata['removable_note'], :blank?, 'value attribute removed'
        assert_predicate metadata['mandatory_note'], :blank?, 'orphaned source-required attribute removed (QA#2)'
        assert_predicate metadata['table_data'], :blank?, 'table attribute removed'
        assert_equal 0, DataCycleCore::Timeseries.where(thing_id: source.id, property: 'series').count, 'timeseries attribute removed (QA#4)'
        assert_equal 0, source.geometries.where(relation: 'geo_area').count, 'geographic attribute removed (QA#4)'
      end

      test 'an incoming relation constrained by template_name rejects a conversion the constraint no longer allows (AK3.1)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-incoming', external_source_id: @external_system.id })
        create_content('Tour', { name: 'Linking Tour', waypoint: [thing.id] })
        thing.reload

        assert_not thing.can_become?(@lift_template, data: { 'name' => 'x' }), "Tour#waypoint is constrained to template_name 'POI', so a Lift is no longer allowed"
        assert(thing.template_conversion_errors(@lift_template, data: { 'name' => 'x' }).any? { |e| e.include?('waypoint') && e.include?('Lift') })
      end

      test 'a content with no blocking relations is feasible (AK3.1)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-clean', external_source_id: @external_system.id })

        assert thing.can_become?(@lift_template, data: { 'name' => 'x' })
        assert_empty thing.template_conversion_errors(@lift_template, data: { 'name' => 'x' })
      end

      test 'an incoming relation constrained by a stored_filter allows a conversion that stays within the filtered type (AK3.1)' do
        thing = create_content('POI', { name: 'Filtered POI', external_key: 'tc-stored-filter-ok', external_source_id: @external_system.id })
        create_content('Event', { name: 'Linking Event', content_location: [thing.id] })
        thing.reload

        assert thing.can_become?(@lift_template, data: { 'name' => 'x' }), 'a Lift is still an Ort, so Event#content_location stays valid'
        assert_empty thing.template_conversion_errors(@lift_template, data: { 'name' => 'x' })
      end

      test 'an incoming relation constrained by a stored_filter rejects a conversion to a type outside the filtered type (AK3.1)' do
        thing = create_content('POI', { name: 'Filtered POI', external_key: 'tc-stored-filter-reject', external_source_id: @external_system.id })
        create_content('Event', { name: 'Linking Event', content_location: [thing.id] })
        thing.reload

        organization_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Organization')

        assert_not thing.can_become?(organization_template, data: { 'name' => 'x' }), 'an Organization is not an Ort, so Event#content_location would no longer be valid'
        assert(thing.template_conversion_errors(organization_template, data: { 'name' => 'x' }).any? { |e| e.include?('content_location') })
      end

      test 'a conversion must satisfy every incoming relation, mixing template_name and stored_filter constraints (AK3.1)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-mixed', external_source_id: @external_system.id })
        create_content('Tour', { name: 'Linking Tour', waypoint: [thing.id] }) # template_name: POI
        create_content('Event', { name: 'Linking Event', content_location: [thing.id] }) # stored_filter: Inhaltstypen/Ort
        thing.reload

        organization_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Organization')
        errors = thing.template_conversion_errors(organization_template, data: { 'name' => 'x' })

        assert_not thing.can_become?(organization_template, data: { 'name' => 'x' })
        assert(errors.any? { |e| e.include?('waypoint') }, 'the template_name relation is reported')
        assert(errors.any? { |e| e.include?('content_location') }, 'the stored_filter relation is reported')
      end

      test 'an incoming relation constrained by both template_name and stored_filter is rejected when only the stored_filter is violated (AK3.1, combined)' do
        source = create_content('TemplateConversionSource', { name: 'Member', mandatory_note: 'x', external_key: 'tc-in-combined', external_source_id: @external_system.id })
        create_content('TemplateConversionContainer', { name: 'Container', member_combined: [source.id] })
        source.reload

        organization_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Organization')

        assert_not source.can_become?(organization_template, data: { 'name' => 'x' }), "Organization is listed in member_combined's template_name, but it is not an Ort -> the stored_filter still rejects it"
        assert(source.template_conversion_errors(organization_template, data: { 'name' => 'x' }).any? { |e| e.include?('member_combined') })
      end

      test 'an outgoing relation constrained by template_name rejects the conversion when a related content no longer fits (AK3.1)' do
        source = create_content('TemplateConversionSource', { name: 'Src', mandatory_note: 'x', external_key: 'tc-out-typed', external_source_id: @external_system.id })
        lift = create_content('Lift', { name: 'A Lift', external_key: 'tc-out-typed-lift', external_source_id: @external_system.id })
        DataCycleCore::ContentContent.create!(content_a_id: source.id, relation_a: 'out_typed', content_b_id: lift.id, order_a: 0)
        source.reload

        target_template = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionTarget')

        assert_not source.can_become?(target_template, data: { 'name' => 'x' }), 'out_typed requires template_name POI, but the related content is a Lift'
        assert(source.template_conversion_errors(target_template, data: { 'name' => 'x' }).any? { |e| e.include?('out_typed') })
      end

      test 'an outgoing relation constrained by a stored_filter allows the conversion when the related content stays within the filtered type (AK3.1)' do
        source = create_content('TemplateConversionSource', { name: 'Src', mandatory_note: 'x', external_key: 'tc-out-ok', external_source_id: @external_system.id })
        lift = create_content('Lift', { name: 'Ort Lift', external_key: 'tc-out-ok-lift', external_source_id: @external_system.id })
        DataCycleCore::ContentContent.create!(content_a_id: source.id, relation_a: 'out_filtered', content_b_id: lift.id, order_a: 0)
        source.reload

        target_template = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionTarget')

        assert source.can_become?(target_template, data: { 'name' => 'x' }), 'a Lift is an Ort, so the out_filtered relation stays valid'
        assert_empty source.template_conversion_errors(target_template, data: { 'name' => 'x' })
      end

      test 'an outgoing relation constrained by a stored_filter rejects the conversion when a related content falls outside the filtered type (AK3.1)' do
        source = create_content('TemplateConversionSource', { name: 'Src', mandatory_note: 'x', external_key: 'tc-out-reject', external_source_id: @external_system.id })
        organization = create_content('Organization', { name: 'An Org', external_key: 'tc-out-reject-org', external_source_id: @external_system.id })
        DataCycleCore::ContentContent.create!(content_a_id: source.id, relation_a: 'out_filtered', content_b_id: organization.id, order_a: 0)
        source.reload

        target_template = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionTarget')

        assert_not source.can_become?(target_template, data: { 'name' => 'x' }), 'an Organization is not an Ort, so the out_filtered relation is invalid'
        assert(source.template_conversion_errors(target_template, data: { 'name' => 'x' }).any? { |e| e.include?('out_filtered') })
      end

      test 'an outgoing relation constrained by both template_name and stored_filter is rejected when only the stored_filter is violated (AK3.1, combined)' do
        source = create_content('TemplateConversionSource', { name: 'Src', mandatory_note: 'x', external_key: 'tc-out-combined', external_source_id: @external_system.id })
        organization = create_content('Organization', { name: 'An Org', external_key: 'tc-out-combined-org', external_source_id: @external_system.id })
        DataCycleCore::ContentContent.create!(content_a_id: source.id, relation_a: 'out_combined', content_b_id: organization.id, order_a: 0)
        source.reload

        target_template = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionTarget')

        assert_not source.can_become?(target_template, data: { 'name' => 'x' }), "Organization is allowed by out_combined's template_name, but it is not an Ort -> the stored_filter still rejects it"
        assert(source.template_conversion_errors(target_template, data: { 'name' => 'x' }).any? { |e| e.include?('out_combined') })
      end

      test 'outgoing stored_filter constraint is enforced even when the converting content has no data_type in the constraint tree' do
        neutral_target_template = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionNeutralTarget')
        source = create_content('TemplateConversionNeutralSource', { name: 'Neutral', external_key: 'tc-neutral-out', external_source_id: @external_system.id })
        org = create_content('Organization', { name: 'An Org', external_key: 'tc-neutral-out-org', external_source_id: @external_system.id })
        DataCycleCore::ContentContent.create!(content_a_id: source.id, relation_a: 'out_ort', content_b_id: org.id, order_a: 0)
        source.reload

        assert_not source.can_become?(neutral_target_template, data: { 'name' => 'x' }), 'Organization is not an Ort; the out_ort constraint must be enforced even though the source has no Inhaltstypen classification'
        assert(source.template_conversion_errors(neutral_target_template, data: { 'name' => 'x' }).any? { |e| e.include?('out_ort') })
      end

      test 'outgoing stored_filter constraint allows the conversion when the related content satisfies it and the source has no data_type in the tree' do
        neutral_target_template = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionNeutralTarget')
        source = create_content('TemplateConversionNeutralSource', { name: 'Neutral', external_key: 'tc-neutral-out-ok', external_source_id: @external_system.id })
        thing = create_content('POI', { name: 'A POI', external_key: 'tc-neutral-out-ok-poi', external_source_id: @external_system.id })
        DataCycleCore::ContentContent.create!(content_a_id: source.id, relation_a: 'out_ort', content_b_id: thing.id, order_a: 0)
        source.reload

        assert source.can_become?(neutral_target_template, data: { 'name' => 'x' }), 'POI is an Ort; the out_ort relation must be valid even though the source has no Inhaltstypen classification'
        assert_empty source.template_conversion_errors(neutral_target_template, data: { 'name' => 'x' })
      end

      test 'an embedded child (i.e., created/managed by its parent via set_embedded, with no import identity of its own) cannot be converted in-place (AK1, AK3, AK5)' do
        parent = create_content('TemplateConversionContainer', {
          name: 'Embedding Parent', external_key: 'tc-embed-parent', external_source_id: @external_system.id,
          embedded_child: [{ 'template_name' => 'TemplateConversionEmbedded', 'name' => 'Embedded child' }]
        })
        embedded = parent.embedded_child.first

        assert_predicate embedded, :embedded?, 'sanity: the child is an embedded content'
        assert_nil embedded.external_key, 'sanity: an embedded child has no import identity of its own'
        assert_equal [parent.id], embedded.content_content_b.map(&:content_a_id), 'sanity: its only inbound relation is the embedding parent'

        assert_not embedded.can_become?('TemplateConversionNeutralTarget', data: { 'name' => 'x' }), 'an embedded child must not be converted: the next parent import would orphan/recreate it'
        assert(embedded.template_conversion_errors('TemplateConversionNeutralTarget', data: { 'name' => 'x' }).any? { |e| e.include?('embedded') && e.include?('parent') }, 'the error must explain that embedded children are managed by their parent')

        assert_raises(DataCycleCore::Error::Import::TemplateConversionError) do
          embedded.update_template!(target_template: 'TemplateConversionNeutralTarget', data: { 'name' => 'x' })
        end
        assert_equal 'TemplateConversionEmbedded', embedded.reload.template_name, 'the embedded child is left untouched'
      end

      test 'required target attributes must be fillable (AK3.2)' do
        unpersisted_thing = DataCycleCore::Thing.new(template_name: 'POI')

        assert_not unpersisted_thing.can_become?(@lift_template, data: {})
        assert(unpersisted_thing.template_conversion_errors(@lift_template, data: {}).any? { |e| e.include?("required property 'name'") })

        assert DataCycleCore::Thing.new(template_name: 'POI').can_become?(@lift_template, data: { 'name' => 'Has Name' })
      end

      test 'the conversion identifies attributes that must be removed (AK3.3)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-removable', external_source_id: @external_system.id })

        assert_includes thing.obsolete_property_names_for(@lift_template), 'price_range', 'POI-only attributes that have no place in a Lift must be removed'
        assert_includes thing.obsolete_property_names_for(@lift_template), 'poi_category', 'POI-only attributes that have no place in a Lift must be removed'
        assert_includes thing.obsolete_property_names_for(@lift_template), 'additional_information', 'POI-only attributes that have no place in a Lift must be removed'

        assert_not_includes thing.obsolete_property_names_for(@lift_template), 'tags', 'global/local attributes must not be removed'
        assert_not_includes thing.obsolete_property_names_for(@lift_template), 'name', 'required attributes must not be removed'
      end

      test 'a generic content update (e.g. via the UI) cannot change the template - template conversion can only happen during an import (AK1)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-ui-update', external_source_id: @external_system.id })

        thing.set_data_hash(data_hash: { 'name' => 'Renamed POI', 'length' => 1234 })
        thing.reload

        assert_equal 'POI', thing.template_name, 'a generic update must not change the type'
        assert_nil thing.try(:length), 'a Lift-only attribute must not be writable on a POI'
      end

      test 'conversion happens in-place keeping the GUID and creating no new record (AK2)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-inplace', external_source_id: @external_system.id })
        id_before = thing.id

        result = create_or_update_content(
          utility_object: @utility_object,
          template: @lift_template,
          data: { 'external_key' => 'tc-inplace', 'name' => 'Converted Lift' }
        )

        assert_equal id_before, result.id
        assert_equal 'Lift', result.reload.template_name
        assert_equal 1, DataCycleCore::Thing.where(external_key: 'tc-inplace', external_source_id: @external_system.id).count
        assert_equal id_before, DataCycleCore::Thing.find_by(external_key: 'tc-inplace', external_source_id: @external_system.id).id
      end

      test 'a feasible conversion re-validates incoming stored_filter relations after the cast (AK3.1, post-conversion)' do
        thing = create_content('POI', { name: 'Linked POI', external_key: 'tc-post-incoming-ok', external_source_id: @external_system.id })
        create_content('Event', { name: 'Linking Event', content_location: [thing.id] }) # stored_filter: Inhaltstypen/Ort
        thing.reload

        result = create_or_update_content(
          utility_object: @utility_object,
          template: @lift_template,
          data: { 'external_key' => 'tc-post-incoming-ok', 'name' => 'Now a Lift' }
        )

        assert_equal 'Lift', result.reload.template_name, 'a Lift is still an Ort, so content_location stays valid through the post-conversion StoredFilter re-check'
        assert_equal thing.id, result.id, 'in-place (same GUID)'
      end

      test 'attributes are mapped via import and obsolete ones removed (AK4 + Detail 1)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-map', external_source_id: @external_system.id, price_range: 'expensive' })

        assert_equal 'expensive', thing.price_range

        create_or_update_content(
          utility_object: @utility_object,
          template: @lift_template,
          data: { 'external_key' => 'tc-map', 'name' => 'Mapped Lift', 'length' => 1500 }
        )
        thing = DataCycleCore::Thing.find(thing.id)

        assert_equal 'Lift', thing.template_name
        assert_equal 1500, thing.length, 'mapped attribute should be written'
        assert_nil thing.try(:price_range), 'obsolete source-only attribute should be removed'
        assert_not_includes Array.wrap(thing.read_attribute(:content)&.keys), 'price_range'
      end

      test 'implausible change leaves content untouched and logs an error (AK5)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-fail', external_source_id: @external_system.id })
        create_content('Tour', { name: 'Blocking Tour', waypoint: [thing.id] })
        thing.reload

        events = capture_notifications('object_template_conversion_failed.datacycle') do
          result = create_or_update_content(
            utility_object: @utility_object,
            template: @lift_template,
            data: { 'external_key' => 'tc-fail', 'name' => 'Converted Lift' },
            config: @config
          )

          assert_equal 'POI', result.reload.template_name, 'content should be returned in its original state if conversion is not feasible'
        end

        assert_equal 'POI', thing.reload.template_name
        assert_equal 1, events.size
        assert_instance_of DataCycleCore::Error::Import::TemplateConversionError, events.first[:exception]
      end

      test 'update_template! raises a TemplateConversionError when called on an infeasible change, in case the caller did not check can_become? before calling update_template! (AK5)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-perform-infeasible', external_source_id: @external_system.id })
        create_content('Tour', { name: 'Blocking Tour', waypoint: [thing.id] })
        thing.reload

        assert_not thing.can_become?(@lift_template, data: { 'name' => 'x' })

        error = assert_raises(DataCycleCore::Error::Import::TemplateConversionError) do
          thing.update_template!(target_template: @lift_template, data: { 'name' => 'x' })
        end

        assert(error.validation_errors.any? { |e| e.include?('waypoint') })
        assert_equal 'POI', thing.reload.template_name, 'update_template! must not convert an infeasible change'
      end

      test 'if feasibility passes, a post-conversion validation error (e.g. caused by a blank name) during re-mapping still rolls back the whole change (AK5)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-rollback', external_source_id: @external_system.id })

        logs = capture_notifications('instrumentation_logging.datacycle') do
          result = create_or_update_content(
            utility_object: @utility_object,
            template: @lift_template,
            data: { 'external_key' => 'tc-rollback', 'name' => '' },
            config: @config
          )

          assert_nil result
        end
        thing.reload

        assert_equal 'POI', thing.template_name, 'the whole conversion (incl. the template switch) must roll back'
        assert_equal 'Test POI', thing.name

        validation_log = logs.find { |l| l[:severity] == 'error' && l[:message].to_s.include?('tc-rollback') }

        assert_not_nil validation_log, 'a validation error should be logged for the rolled-back item'
        assert_match(/name/i, validation_log[:message], 'the logged error should concern the required name attribute')
      end

      test 'a conversion the pre-check allows but the post-conversion StoredFilter re-check rejects is rolled back, leaving the content untouched (AK5, post-conversion)' do
        thing = create_content('POI', { name: 'Excluded POI', external_key: 'tc-post-rollback', external_source_id: @external_system.id })
        # member_not_lift excludes Lift via a not_-prefixed filter the pre-check does not parse: a POI passes it, a Lift does not
        create_content('TemplateConversionContainer', { name: 'Excluder', member_not_lift: [thing.id] })
        thing.reload

        assert_empty thing.template_conversion_errors(@lift_template, data: { 'name' => 'x' }), 'pre-conversion check is clean: it does not parse the exclusion filter'

        events = capture_notifications('object_template_conversion_failed.datacycle') do
          result = create_or_update_content(
            utility_object: @utility_object,
            template: @lift_template,
            data: { 'external_key' => 'tc-post-rollback', 'name' => 'Now a Lift' },
            config: @config
          )

          assert_equal 'POI', result.reload.template_name, 'the post-conversion StoredFilter check rejects (Lift is excluded), rolling back the conversion'
        end

        assert_equal 'POI', thing.reload.template_name, 'the content is left untouched'
        assert_equal 1, events.size
        assert_instance_of DataCycleCore::Error::Import::TemplateConversionError, events.first[:exception]
        assert(events.first[:exception].validation_errors.any? { |e| e.include?('member_not_lift') }, 'the post-conversion error names the violating incoming relation')
      end

      test 'a conversion the pre-check allows but the post-conversion StoredFilter re-check rejects on an outgoing relation is rolled back (AK3.1, post-conversion, outgoing)' do
        source = create_content('TemplateConversionSource', { name: 'Src', mandatory_note: 'x', external_key: 'tc-out-post-rollback', external_source_id: @external_system.id })
        lift = create_content('Lift', { name: 'A Lift', external_key: 'tc-out-post-lift', external_source_id: @external_system.id })
        # out_not_lift excludes Lift via a not_-prefixed filter the pre-check does not parse
        DataCycleCore::ContentContent.create!(content_a_id: source.id, relation_a: 'out_not_lift', content_b_id: lift.id, order_a: 0)
        source.reload

        target_template = DataCycleCore::ThingTemplate.find_by(template_name: 'TemplateConversionTarget')

        assert_empty source.template_conversion_errors(target_template, data: { 'name' => 'x' }), 'pre-conversion check is clean: it does not parse the exclusion filter on the outgoing relation'

        events = capture_notifications('object_template_conversion_failed.datacycle') do
          result = create_or_update_content(
            utility_object: @utility_object,
            template: target_template,
            data: { 'external_key' => 'tc-out-post-rollback', 'name' => 'Converted' },
            config: @config
          )

          assert_equal 'TemplateConversionSource', result.reload.template_name, 'the outgoing post-conversion StoredFilter check rejects (a linked Lift is excluded), rolling back the conversion'
        end

        assert_equal 'TemplateConversionSource', source.reload.template_name, 'the content is left untouched'
        assert_equal 1, events.size
        assert(events.first[:exception].validation_errors.any? { |e| e.include?('out_not_lift') }, 'the post-conversion error names the violating outgoing relation')
      end

      test 'a successful template change fires the instrumentation event (Detail 2)' do
        create_content('POI', { name: 'Test POI', external_key: 'tc-instrument', external_source_id: @external_system.id })

        events = capture_notifications('object_template_converted.datacycle') do
          create_or_update_content(
            utility_object: @utility_object,
            template: @lift_template,
            data: { 'external_key' => 'tc-instrument', 'name' => 'Converted Lift' },
            config: @config
          )
        end

        assert_equal 1, events.size
        assert_equal 'POI', events.first[:previous_template_name]
        assert_equal 'Lift', events.first[:template_name]
        assert_equal @external_system, events.first[:external_system]
      end

      test 'no instrumentation event when the template does not change (Detail 2)' do
        create_content('POI', { name: 'Test POI', external_key: 'tc-noop', external_source_id: @external_system.id })

        events = capture_notifications('object_template_converted.datacycle') do
          create_or_update_content(
            utility_object: @utility_object,
            template: DataCycleCore::ThingTemplate.find_by(template_name: 'POI'),
            data: { 'external_key' => 'tc-noop', 'name' => 'Still a POI' },
            config: @config
          )
        end

        assert_empty events
      end

      test 'template_conversion_errors returns a descriptive error for an unknown template name string' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-unknown-tmpl', external_source_id: @external_system.id })

        assert_not thing.can_become?('NonExistentTemplate', data: {})
        assert(thing.template_conversion_errors('NonExistentTemplate', data: {}).any? { |e| e.include?('NonExistentTemplate') })
      end

      test 'update_template! raises TemplateConversionError when passed an unknown template name string' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-str-unknown', external_source_id: @external_system.id })

        assert_raises(DataCycleCore::Error::Import::TemplateConversionError) do
          thing.update_template!(target_template: 'NonExistentTemplate', data: {})
        end
      end

      test 'Thing#can_become? exposes the feasibility check (Detail 3)' do
        thing = create_content('POI', { name: 'Test POI', external_key: 'tc-can-become', external_source_id: @external_system.id })

        assert thing.can_become?(@lift_template, data: { 'name' => 'x' }), 'a clean POI can become a Lift'
        assert thing.can_become?('Lift', data: { 'name' => 'x' }), 'the target may be passed as a template name'

        create_content('Tour', { name: 'Linking Tour', waypoint: [thing.id] })
        thing.reload

        assert_not thing.can_become?(@lift_template, data: { 'name' => 'x' }), 'a Tour#waypoint blocks POI -> Lift'
        assert(thing.template_conversion_errors(@lift_template, data: { 'name' => 'x' }).any? { |e| e.include?('waypoint') })
      end

      test 'changing template_name cleans up obsolete attributes via the after_update callback (Detail 3)' do
        source = create_content('TemplateConversionSource', {
          name: 'Callback Source', external_key: 'tc-callback', external_source_id: @external_system.id,
          local_note: 'keep me', removable_note: 'drop me', mandatory_note: 'drop me too',
          series: [{ 'timestamp' => Time.zone.now, 'value' => 1 }]
        })

        assert_equal 1, DataCycleCore::Timeseries.where(thing_id: source.id, property: 'series').count

        source.update!(template_name: 'TemplateConversionTarget')
        source = DataCycleCore::Thing.find(source.id)

        assert_equal 'TemplateConversionTarget', source.template_name
        assert_equal 'keep me', source.local_note, 'local attribute is preserved'

        metadata = source.read_attribute(:metadata) || {}

        assert_predicate metadata['removable_note'], :blank?, 'obsolete value attribute removed by the callback'
        assert_predicate metadata['mandatory_note'], :blank?, 'orphaned source-required attribute removed by the callback'
        assert_equal 0, DataCycleCore::Timeseries.where(thing_id: source.id, property: 'series').count, 'obsolete timeseries removed by the callback'
      end

      test 'a content can be converted repeatedly, including back to its original type, keeping its GUID (QA: reversibility)' do
        thing = create_content('POI', { name: 'Reversible', external_key: 'tc-reconvert', external_source_id: @external_system.id })
        id_before = thing.id

        create_or_update_content(
          utility_object: @utility_object,
          template: @lift_template,
          data: { 'external_key' => 'tc-reconvert', 'name' => 'As Lift' }
        )

        assert_equal 'Lift', DataCycleCore::Thing.find(thing.id).template_name

        create_or_update_content(
          utility_object: @utility_object,
          template: DataCycleCore::ThingTemplate.find_by(template_name: 'POI'),
          data: { 'external_key' => 'tc-reconvert', 'name' => 'Back As POI' }
        )
        thing = DataCycleCore::Thing.find(thing.id)

        assert_equal id_before, thing.id, 'GUID is stable across repeated conversions'
        assert_equal 'POI', thing.template_name
        assert_equal 'Back As POI', thing.name
        assert_equal 1, DataCycleCore::Thing.where(external_key: 'tc-reconvert', external_source_id: @external_system.id).count
      end

      test '[#49217] regression: re-importing a deskline POI (essen & trinken) converts in-place to Gastronomischer Betrieb (FoodEstablishment)' do
        poi_template = DataCycleCore::ThingTemplate.find_by(template_name: 'POI')
        gastronomy_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Gastronomischer Betrieb')
        poi_category_ids = get_classification_ids('POI - Kategorien', ['Restaurant'])

        assert_not_includes gastronomy_template.property_names, 'poi_category', 'guard: poi_category is genuinely POI-only (not defined on the target)'

        poi = create_or_update_content(
          utility_object: @utility_object,
          template: poi_template,
          data: { 'external_key' => 'deskline-gastro-1', 'name' => 'Restaurant Adler', 'poi_category' => poi_category_ids }
        )
        poi.reload
        id_after_initial_poi_import = poi.id

        assert_equal 'POI', poi.template_name, 'first import creates a POI'
        assert_equal 'Restaurant Adler', poi.name
        assert_equal 1, poi.classification_contents.where(relation: 'poi_category').count, 'the POI-only attribute is set'

        events = capture_notifications('object_template_converted.datacycle') do
          create_or_update_content(
            utility_object: @utility_object,
            template: gastronomy_template,
            data: { 'external_key' => 'deskline-gastro-1', 'name' => 'Restaurant Adler' },
            config: @config
          )
        end
        poi = DataCycleCore::Thing.find(poi.id)

        assert_equal id_after_initial_poi_import, poi.id, 'GUID is preserved (in-place, AK2)'
        assert_equal 'Gastronomischer Betrieb', poi.template_name
        assert_equal 'Restaurant Adler', poi.name, 'mapped via import (AK4)'
        assert_equal 0, poi.classification_contents.where(relation: 'poi_category').count, 'a POI-only attribute the target does not define is removed (Detail 1)'
        assert_equal 1, DataCycleCore::Thing.where(external_key: 'deskline-gastro-1', external_source_id: @external_system.id).count, 'no new record'
        assert_equal 1, events.size
        assert_equal 'Gastronomischer Betrieb', events.first[:template_name]
      end

      test 'an attribute the target still defines (e.g. price_range for POI -> FoodEstablishment) is not carried over implicitly - re-supplying it (or not) is the importer\'s responsibility (QA, AK4)' do
        gastronomy_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Gastronomischer Betrieb')

        assert_includes gastronomy_template.property_names, 'price_range', 'guard: price_range is defined on the target, too'

        omitted = create_content('POI', { name: 'Adler', external_key: 'tc-shared-omitted', external_source_id: @external_system.id, price_range: 'moderate' })

        assert_equal 'moderate', omitted.price_range

        create_or_update_content(
          utility_object: @utility_object,
          template: gastronomy_template,
          data: { 'external_key' => 'tc-shared-omitted', 'name' => 'Adler' }
        )
        omitted = DataCycleCore::Thing.find(omitted.id)

        assert_equal 'Gastronomischer Betrieb', omitted.template_name
        assert_nil omitted.try(:price_range), 'a shared attribute the import does not re-supply is not carried over by the conversion'

        resupplied = create_content('POI', { name: 'Krone', external_key: 'tc-shared-resupplied', external_source_id: @external_system.id, price_range: 'moderate' })

        create_or_update_content(
          utility_object: @utility_object,
          template: gastronomy_template,
          data: { 'external_key' => 'tc-shared-resupplied', 'name' => 'Krone', 'price_range' => 'expensive' }
        )
        resupplied = DataCycleCore::Thing.find(resupplied.id)

        assert_equal 'Gastronomischer Betrieb', resupplied.template_name
        assert_equal 'expensive', resupplied.price_range, 'the conversion importer can re-supply a shared attribute, which sets the new value'
      end

      test 'can_become? treats the target equivalently whether given as a ThingTemplate, a template Thing (as the importer passes it), a String or a Symbol' do
        thing = create_content('POI', { name: 'Poly POI', external_key: 'tc-poly-ok', external_source_id: @external_system.id })
        template_thing = DataCycleCore::Thing.new(template_name: 'Lift') # exactly what the importer's load_template builds

        assert thing.can_become?(@lift_template, data: { 'name' => 'x' }), 'ThingTemplate'
        assert thing.can_become?(template_thing, data: { 'name' => 'x' }), 'template Thing (importer case)'
        assert thing.can_become?('Lift', data: { 'name' => 'x' }), 'String'
        assert thing.can_become?(:Lift, data: { 'name' => 'x' }), 'Symbol'
      end

      test 'template_conversion_errors are identical regardless of how the target template is expressed (ThingTemplate / Thing / String / Symbol)' do
        thing = create_content('POI', { name: 'Poly POI', external_key: 'tc-poly-block', external_source_id: @external_system.id })
        create_content('Tour', { name: 'Blocking Tour', waypoint: [thing.id] }) # waypoint is constrained to template_name POI -> blocks Lift
        thing.reload

        template_thing = DataCycleCore::Thing.new(template_name: 'Lift')
        expected = thing.template_conversion_errors(@lift_template, data: { 'name' => 'x' })

        assert(expected.any? { |e| e.include?('waypoint') }, 'guard: the blocking incoming relation makes this infeasible')
        assert_equal expected, thing.template_conversion_errors(template_thing, data: { 'name' => 'x' }), 'template Thing'
        assert_equal expected, thing.template_conversion_errors('Lift', data: { 'name' => 'x' }), 'String'
        assert_equal expected, thing.template_conversion_errors(:Lift, data: { 'name' => 'x' }), 'Symbol'
      end

      test 'update_template! accepts a template Thing as its target (the type the importer actually passes via load_template)' do
        thing = create_content('POI', { name: 'Poly POI', external_key: 'tc-poly-update', external_source_id: @external_system.id })
        template_thing = DataCycleCore::Thing.new(template_name: 'Lift')

        result = thing.update_template!(target_template: template_thing, data: { 'name' => 'x' })

        assert_equal 'Lift', result.template_name
        assert_equal 'Lift', DataCycleCore::Thing.find(thing.id).template_name, 'the row was converted in place'
      end

      test 'obsolete_property_names_for treats the target equivalently whether given as a ThingTemplate, a Thing or a String' do
        thing = create_content('POI', { name: 'Poly POI', external_key: 'tc-poly-obsolete', external_source_id: @external_system.id })
        template_thing = DataCycleCore::Thing.new(template_name: 'Lift')
        expected = thing.obsolete_property_names_for(@lift_template)

        assert_includes expected, 'price_range', 'guard: a POI-only attribute is obsolete in a Lift'
        assert_equal expected, thing.obsolete_property_names_for(template_thing), 'Thing'
        assert_equal expected, thing.obsolete_property_names_for('Lift'), 'String'
      end

      private

      def capture_notifications(name)
        events = []
        subscriber = ActiveSupport::Notifications.subscribe(name) { |*args| events << args.last }
        yield
        events
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
    end
  end
end
