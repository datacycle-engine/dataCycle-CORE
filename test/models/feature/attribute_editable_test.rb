# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Feature::Base#attribute_editable? answers the question an attribute *editor* asks -- so it
  # answers false for an attribute that has none, however writable that attribute is. This is the
  # canonical statement of that split, because the two shapes look interchangeable and are not.
  class AttributeEditableTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @current_user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
    end

    setup do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'AttributeEditable' })
    end

    def bare_can?(key)
      @current_user.can?(:update, DataCycleCore::DataAttribute.new(key, @content.properties_for(key), {}, @content, :update))
    end

    # What the pixies write: an attribute with an editor, which is what makes their wands and their
    # endpoints answerable by the same question.
    test 'an attribute with an editor is editable' do
      assert DataCycleCore::Feature::Base.attribute_editable?(@content, 'description', @current_user)
    end

    # What FocusPointEditor and GravityEditor write: `:visible: api` attributes with no editor at
    # all, persisted through PATCH /things/:id/update_focus_point and /update_gravity. Ability#
    # can_attribute? rejects them, so those two features ask the bare per-attribute right instead --
    # asking this method would disable both editors outright.
    test 'an attribute written through a feature endpoint has no editor and is not editable' do
      focus_point_key = DataCycleCore::Feature::FocusPointEditor.attribute_keys(@content).first

      assert_not DataCycleCore::Feature::Base.attribute_editable?(@content, focus_point_key, @current_user)
      assert bare_can?(focus_point_key), 'expected the bare per-attribute right to still allow it'
      assert DataCycleCore::Feature::FocusPointEditor.user_can_edit?(@content, @current_user)
    end

    test 'a key the template does not carry is not editable' do
      assert_not DataCycleCore::Feature::Base.attribute_editable?(@content, 'not_a_property', @current_user)
      assert_not DataCycleCore::Feature::Base.attribute_editable?(@content, 'description', nil)
      assert_not DataCycleCore::Feature::Base.attribute_editable?(nil, 'description', @current_user)
    end
  end
end
