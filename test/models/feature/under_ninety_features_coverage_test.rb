# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for Feature::* class-methods left below 90%. Each feature is a
    # Feature::Base subclass whose class-methods read `configuration`/`config`/
    # `enabled_serializers`/`ordered_classifications`; those collaborators are stubbed
    # so the selector/label/dispatch bodies run over plain doubles without any config
    # files or database access.
    class UnderNinetyFeaturesCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # --- FocusPointEditor -------------------------------------------------
      test 'FocusPointEditor exposes its controller and routes modules' do
        assert_kind_of Module, DataCycleCore::Feature::FocusPointEditor.controller_module
        assert_kind_of Module, DataCycleCore::Feature::FocusPointEditor.routes_module
      end

      test 'FocusPointEditor#user_can_edit? requires attribute update and edit rights' do
        user = Object.new
        user.define_singleton_method(:can?) { |*| true }
        content = Object.new
        content.define_singleton_method(:properties_for) { |_key| {} }

        DataCycleCore::Feature::FocusPointEditor.stub(:allowed?, ->(*) { true }) do
          DataCycleCore::Feature::FocusPointEditor.stub(:attribute_keys, ->(*) { ['focus_point'] }) do
            assert DataCycleCore::Feature::FocusPointEditor.user_can_edit?(content, user)
          end
        end
      end

      test 'FocusPointEditor#apply_focus_point! writes a gravity option only for present coordinates' do
        DataCycleCore::Feature::FocusPointEditor.stub(:attribute_keys, ->(*) { ['x', 'y'] }) do
          options = {}
          DataCycleCore::Feature::FocusPointEditor.apply_focus_point!(options, { 'x' => 10, 'y' => 20 })

          assert_equal 'fp:10:20', options['gravity']

          blank = {}
          DataCycleCore::Feature::FocusPointEditor.apply_focus_point!(blank, { 'x' => nil, 'y' => nil })

          assert_nil blank['gravity']
        end
      end

      # --- ReportGenerator --------------------------------------------------
      test 'ReportGenerator resolves global and content report definitions' do
        cfg = {
          'global' => { 'rep1' => { 'enabled' => true, 'class' => 'GlobalReport', 'params' => { 'a' => 1 } } },
          'content' => { 'rep2' => { 'enabled' => true, 'class' => 'ContentReport', 'params' => {} } }
        }

        DataCycleCore::Feature::ReportGenerator.stub(:configuration, ->(*) { { config: cfg } }) do
          content = struct_double(id: 'x')

          assert_equal ['GlobalReport', { 'a' => 1 }], DataCycleCore::Feature::ReportGenerator.by_identifier('rep1')
          assert_equal ['ContentReport', {}], DataCycleCore::Feature::ReportGenerator.by_identifier('rep2', content)
          assert_equal cfg['global'], DataCycleCore::Feature::ReportGenerator.global_reports
          assert_equal cfg['content'], DataCycleCore::Feature::ReportGenerator.content_reports(content)
        end
      end

      # --- CopyableAttribute ------------------------------------------------
      test 'CopyableAttribute derives from-attribute label and titles' do
        content = Object.new
        content.define_singleton_method(:properties_for) { |_key| { 'label' => 'Source' } }

        DataCycleCore::Feature::CopyableAttribute.stub(:configuration, ->(*) { { from: 'source_attr', clear_from_attribute: true } }) do
          assert_equal 'source_attr', DataCycleCore::Feature::CopyableAttribute.from_attribute(content)
          assert DataCycleCore::Feature::CopyableAttribute.clear_from_attribute?(content)
          assert_equal 'Source', DataCycleCore::Feature::CopyableAttribute.from_attribute_label(content)
          assert_kind_of String, DataCycleCore::Feature::CopyableAttribute.link_title(content, 'de')
          assert_kind_of String, DataCycleCore::Feature::CopyableAttribute.clear_title(content, 'de')
        end
      end

      # --- UserRegistration -------------------------------------------------
      test 'UserRegistration#users_outside_grace_period ORs the privacy-policy conditions' do
        cfg = {
          'consent_grace_period' => 1.day,
          'terms_condition_updated_at' => 2.days.ago,
          'privacy_policy_updated_at' => 2.days.ago
        }

        DataCycleCore::Feature::UserRegistration.stub(:configuration, ->(*) { cfg }) do
          assert_kind_of ActiveRecord::Relation, DataCycleCore::Feature::UserRegistration.users_outside_grace_period
        end
      end

      test 'UserRegistration#users_to_notify collects group and configured emails' do
        cfg = { new_user_notification: { user_group: 'Does Not Exist', email: 'notify@example.com' } }

        DataCycleCore::Feature::UserRegistration.stub(:configuration, ->(*) { cfg }) do
          assert_equal ['notify@example.com'], DataCycleCore::Feature::UserRegistration.users_to_notify
        end
      end

      test 'UserRegistration#notify_users delivers the registration mail' do
        delivered = false
        mail = Object.new
        mail.define_singleton_method(:deliver_now) { delivered = true }

        DataCycleCore::Feature::UserRegistration.stub(:configuration, ->(*) { {} }) do
          DataCycleCore::UserRegistrationMailer.stub(:notify, ->(*) { mail }) do
            DataCycleCore::Feature::UserRegistration.notify_users(struct_double(email: 'new@example.com'))
          end
        end

        assert delivered
      end

      # --- Serialize --------------------------------------------------------
      test 'Serialize#asset_versions returns the asset hash or an empty hash' do
        DataCycleCore::Feature::Serialize.stub(:configuration, ->(*) { { 'serializers' => { 'asset' => { 'thumb' => {} } } } }) do
          assert_equal({ 'thumb' => {} }, DataCycleCore::Feature::Serialize.asset_versions)
        end

        DataCycleCore::Feature::Serialize.stub(:configuration, ->(*) { { 'serializers' => { 'asset' => 'nope' } } }) do
          assert_empty DataCycleCore::Feature::Serialize.asset_versions
        end
      end

      test 'Serialize#serializer_for_content resolves string and hash serializer definitions' do
        DataCycleCore::Feature::Serialize.stub(:enabled_serializers, { 'a' => 'DataCycleCore::Serialize::Serializer::Json', 'b' => { 'class' => 'DataCycleCore::Serialize::Serializer::Xml' } }) do
          assert_equal DataCycleCore::Serialize::Serializer::Json, DataCycleCore::Feature::Serialize.serializer_for_content('a')
          assert_equal DataCycleCore::Serialize::Serializer::Xml, DataCycleCore::Feature::Serialize.serializer_for_content('b')
          assert DataCycleCore::Feature::Serialize.send(:serializer_enabled?, 'a')
        end
      end

      # --- LifeCycle --------------------------------------------------------
      test 'LifeCycle derives archive id, creatable stages and default alias id' do
        ordered = { 'Entwurf' => { id: '1' }, 'Archiv' => { id: '2' } }.with_indifferent_access

        DataCycleCore::Feature::LifeCycle.stub(:ordered_classifications, ->(*) { ordered }) do
          DataCycleCore::Feature::LifeCycle.stub(:archive_name, ->(*) { 'Archiv' }) do
            assert_equal '2', DataCycleCore::Feature::LifeCycle.archive_id
          end

          assert_equal [['Entwurf', '1']], DataCycleCore::Feature::LifeCycle.creatable_stages

          content = struct_double(schema: { 'properties' => { 'status' => { 'default_value' => 'Entwurf' } } })

          DataCycleCore::Feature::LifeCycle.stub(:allowed_attribute_keys, ->(*) { ['status'] }) do
            assert_equal '1', DataCycleCore::Feature::LifeCycle.default_alias_id(content)
          end
        end
      end

      # --- Releasable -------------------------------------------------------
      test 'Releasable#send_reminder_email returns early without data links' do
        assert_nil DataCycleCore::Feature::Releasable.send_reminder_email(nil)
      end

      test 'Releasable#send_reminder_email mails each non-nil receiver group' do
        receiver = Object.new
        with_receiver = Object.new
        with_receiver.define_singleton_method(:receiver) { receiver }
        with_receiver.define_singleton_method(:[]) { |key| { id: 'link-1' }[key] }
        without_receiver = Object.new
        without_receiver.define_singleton_method(:receiver) { nil }
        without_receiver.define_singleton_method(:[]) { |key| { id: 'link-2' }[key] }

        data_links = Object.new
        data_links.define_singleton_method(:includes) { |*| [with_receiver, without_receiver] }

        reminded = []
        mail = Object.new
        mail.define_singleton_method(:deliver_later) { :queued }

        DataCycleCore::ReleasableSubscriptionMailer.stub(:remind_receiver, lambda { |rcv, ids|
          reminded << [rcv, ids]
          mail
        }) do
          DataCycleCore::Feature::Releasable.send_reminder_email(data_links)
        end

        assert_equal [[receiver, ['link-1']]], reminded
      end

      # --- Content::Overlay -------------------------------------------------
      test 'Content::Overlay#relevant_property_names returns overlay pairs, super or empty' do
        super_module = Module.new do
          def relevant_property_names(_key)
            [:from_super]
          end
        end

        host_class = Class.new do
          include super_module
          include DataCycleCore::Feature::Content::Overlay

          def initialize(properties)
            @properties = properties
          end

          def property?(name)
            @properties.key?(name)
          end

          def properties_for(name)
            @properties[name] || {}
          end
        end

        host = host_class.new(
          'plain' => {},
          'overlaid' => { 'features' => { 'overlay' => { 'overlay_for' => 'base_property' } } }
        )

        blank_key = Object.new
        blank_key.define_singleton_method(:attribute_name_from_key) { '' }
        plain_key = Object.new
        plain_key.define_singleton_method(:attribute_name_from_key) { 'plain' }
        overlaid_key = Object.new
        overlaid_key.define_singleton_method(:attribute_name_from_key) { 'overlaid' }

        assert_empty host.relevant_property_names(blank_key)
        assert_equal [:from_super], host.relevant_property_names(plain_key)
        assert_equal ['base_property', 'overlaid'], host.relevant_property_names(overlaid_key)
      end
    end
  end
end
