# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Unit tests for the write whitelist. Two properties carry the weight here: WHAT is not in it
    # (the internal importer attributes, with which a write would turn into an overwrite of arbitrary
    # records) and the back-translation of the API names, without which a client cannot find out the
    # right attribute name over MCP at all.
    class WritableAttributesTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @content = DataCycleCore::Thing.new(template_name: 'Artikel')
      end

      # id/external_key/external_system_data are writable for an importer (see
      # Content::Content::IMPORTABLE_INTERNAL_PROPERTY_NAMES) and must precisely NOT be over MCP: an
      # id set by the model turns a create into an overwrite of some existing record, and an
      # external_key assigns the content to an import source that overwrites it on its next run.
      test 'the internal importer attributes are never writable' do
        DataCycleCore::Content::Content::IMPORTABLE_INTERNAL_PROPERTY_NAMES.each do |name|
          assert_not_includes writable.names, name
          assert_not_includes writable.to_a.pluck(:attribute), name
        end
      end

      test 'the whitelist is the importable set minus exactly those internal attributes' do
        expected = @content.importable_property_names - DataCycleCore::Content::Content::IMPORTABLE_INTERNAL_PROPERTY_NAMES

        assert_equal expected.sort, writable.names.sort
      end

      test 'a translatable attribute is marked as such so a client knows the locale matters' do
        name = writable.to_a.find { |a| a[:attribute] == 'name' }

        assert_predicate name, :present?
        assert name[:translatable]
      end

      # On every attribute without api.unit_text/unit_code the label is the ONLY statement of the
      # unit ("Duration (min)"). A label that is an i18n key hash in the template definition must
      # therefore not be dropped -- a client without a unit and without a label writes hours into a
      # minutes field.
      test 'every attribute carries a resolved label, never a raw i18n key hash' do
        writable.to_a.each do |attribute|
          assert_predicate attribute[:label], :present?, "attribute '#{attribute[:attribute]}' has no label"
          assert_kind_of ::String, attribute[:label]
        end
      end

      test 'the label comes back in the requested language' do
        localized = DataCycleCore::Mcp::WritableAttributes.new(@content, locale: :en).to_a.find { |a| a[:attribute] == 'name' }

        assert_predicate localized[:label], :present?
        assert_kind_of ::String, localized[:label]
      end

      # The reason for the separate tool: get_schema/list_attributes return the api_name column of
      # the reading v4 API, while writing goes through the internal property name. Both names in one
      # entry are the only way to get from the read side to the write side.
      test 'entries carry the api name next to the internal one' do
        with_api_name = writable.to_a.select { |a| a[:api_name].present? }

        assert_predicate with_api_name, :present?, 'no attribute has an api_name -- the bridge to get_schema is untestable'
        with_api_name.each { |a| assert_predicate a[:attribute], :present? }
      end

      test 'suggestions_for translates a rejected api name back into the writable key' do
        renamed = writable.to_a.find { |a| a[:api_name].present? && a[:api_name] != a[:attribute] }
        skip 'template has no attribute with a differing api name' if renamed.blank?

        assert_equal({ renamed[:api_name] => renamed[:attribute] }, writable.suggestions_for([renamed[:api_name]]))
      end

      test 'suggestions_for stays empty for a name that is no api name either' do
        assert_empty writable.suggestions_for(['not_a_real_attribute'])
        assert_empty writable.suggestions_for([])
        assert_empty writable.suggestions_for(nil)
      end

      # Nested paths (address.street_address) share the api_name namespace but are not writable as a
      # flat key -- suggesting one would send the client back into the same error.
      test 'no nested path leaks into the writable names' do
        assert_empty(writable.names.select { |name| name.include?('.') })
      end

      private

      def writable
        @writable ||= DataCycleCore::Mcp::WritableAttributes.new(@content)
      end
    end
  end
end
