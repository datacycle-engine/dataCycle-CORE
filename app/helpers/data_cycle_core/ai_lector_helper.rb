# frozen_string_literal: true

module DataCycleCore
  module AiLectorHelper
    # def ai_lector_dropdown(content, key)
    #   dropdown_id = "#{sanitize_to_id(key)}-ai-lector-dropdown"

    #   content_tag(:div, class: 'ai-lector-dropdown-container') do
    #     concat(ai_lector_dropdown_button(dropdown_id))
    #     concat(ai_lector_dropdown_content(dropdown_id, content, key))
    #   end
    # end

    # def ai_lector_available_properties(content, key, direct_user_input_allowed)
    #   return {} unless direct_user_input_allowed

    #   scope_object = content.try(:root) || content.try(:parent) || content
    #   translatable_props = scope_object.try(:translatable_property_names) || []

    #   regular_props = scope_object.property_names.reject do |prop|
    #     prop == key || prop == 'id' || prop == 'dummy' || prop.to_s.start_with?('_')
    #   end

    #   if content.try(:parent) && scope_object.respond_to?(:embedded_property_names)
    #     sibling_props = scope_object.embedded_property_names.flat_map { |embedded_prop|
    #       embedded_objects = Array.wrap(scope_object.try(embedded_prop))
    #       embedded_objects.filter_map do |embedded_obj|
    #         next if embedded_obj == content

    #         embedded_obj.property_names.reject do |prop|
    #           prop == key || prop == 'id' || prop == 'dummy' || prop.to_s.start_with?('_')
    #         end
    #       end
    #     }.flatten.uniq

    #     regular_props = (regular_props + sibling_props).uniq
    #   end

    #   regular_props.filter_map do |prop|
    #     raw_value = scope_object.try(prop)

    #     if raw_value.blank? && content.try(:parent)
    #       scope_object.embedded_property_names.each do |embedded_prop|
    #         embedded_objects = Array.wrap(scope_object.try(embedded_prop))
    #         embedded_objects.each do |embedded_obj|
    #           next if embedded_obj == content

    #           if embedded_obj.respond_to?(prop)
    #             raw_value = embedded_obj.try(prop)
    #             break if raw_value.present?
    #           end
    #         end
    #         break if raw_value.present?
    #       end
    #     end

    #     if raw_value.present?
    #       processed_value = process_property_value(raw_value)

    #       if processed_value.present?
    #         {
    #           name: prop,
    #           value: processed_value.to_s,
    #           translatable: translatable_props.include?(prop)
    #         }
    #       end
    #     end
    #   end
    # end

    private

    # def ai_lector_dropdown_button(dropdown_id)
    #   button_tag(
    #     tag.i(class: 'fa fa-magic'),
    #     type: 'button',
    #     data: { toggle: dropdown_id },
    #     class: 'ai-lector-dropdown-button'
    #   )
    # end

    # def ai_lector_dropdown_content(dropdown_id, content, key)
    #   tag.div(
    #     class: 'dropdown-pane ai-lector-dropdown',
    #     id: dropdown_id,
    #     data: { hover: false, dropdown: true, close_on_click: true, position: 'bottom' }
    #   ) do
    #     tag.ul(class: 'no-bullet') do
    #       concat(ai_lector_tips_section(content, key))
    #       concat(ai_lector_improvements_section(content, key))
    #     end
    #   end
    # end

    # def ai_lector_tips_section(content, key)
    #   tips = DataCycleCore::Feature['AiLector'].tips_config(content, key)
    #   return '' unless tips&.any?

    #   content_tag(:li, class: 'ai-lector-section-header') {
    #     tag.strong(t('feature.ai_lector.section.tips', default: 'Tips'))
    #   } +
    #     tips.map { |k, _v| ai_lector_tip_item(content, key, k, 'tips') }.join
    # end

    # def ai_lector_improvements_section(content, key)
    #   improvements = DataCycleCore::Feature['AiLector'].improvements_config(content, key)
    #   return '' unless improvements&.any?

    #   content_tag(:li, class: 'ai-lector-section-header') {
    #     tag.strong(t('feature.ai_lector.section.improvements', default: 'Improvements'))
    #   } +
    #     improvements.map { |k, _v| ai_lector_tip_item(content, key, k, 'improvements') }.join
    # end

    def ai_lector_tip_item(content, key, tip_key, prompt_type)
      metadata = get_ai_lector_metadata(content, key, tip_key, prompt_type)

      # For tips, just use the tip key name (prompt, prompt2, prompt3)
      # For improvements, use the localized title from metadata
      if prompt_type == 'tips'
        title = tip_key.to_s
        description = nil # Tips don't have descriptions
      else
        title = metadata[:title].presence || t("feature.ai_lector.#{prompt_type}.#{tip_key}", default: tip_key.to_s, locale: active_ui_locale)
        description = metadata[:description]
      end

      feedback_loop_allowed = DataCycleCore::Feature['AiLector'].feedback_loop_allowed?(content, key, tip_key, prompt_type)
      direct_user_input_allowed = DataCycleCore::Feature['AiLector'].direct_user_input_allowed?(content, key, tip_key, prompt_type)

      available_properties = ai_lector_available_properties(content, key, direct_user_input_allowed)

      content_tag(:li, class: 'ai-lector-tip-container') do
        concat(
          button_tag(
            title,
            class: 'ai-lector-tips-button ai-lector-button',
            type: 'button',
            data: {
              template_name: content.template_name,
              content_id: content.id,
              tip_key: tip_key,
              key: key,
              locale: I18n.locale,
              prompt_type: prompt_type,
              description: description,
              feedback_loop_allowed: feedback_loop_allowed,
              direct_user_input_allowed: direct_user_input_allowed,
              available_properties: available_properties.to_json
            }
          )
        )
        concat(tag.div(class: 'ai-lector-result'))
      end
    end

    # def get_ai_lector_metadata(content, key, tip_key, prompt_type)
    #   case prompt_type
    #   when 'tips'
    #     DataCycleCore::Feature['AiLector'].get_tip_metadata(content, key, tip_key, active_ui_locale)
    #   when 'improvements'
    #     DataCycleCore::Feature['AiLector'].get_improvement_metadata(content, key, tip_key, active_ui_locale)
    #   else
    #     {}
    #   end
    # end

    # def process_property_value(raw_value)
    #   case raw_value
    #   when ActiveRecord::Relation, ActiveRecord::AssociationRelation
    #     process_relation_value(raw_value)
    #   when String, Numeric, TrueClass, FalseClass
    #     raw_value.to_s
    #   else
    #     process_object_value(raw_value)
    #   end
    # end

    # def process_relation_value(raw_value)
    #   return nil unless raw_value.respond_to?(:count) && raw_value.any?

    #   items = raw_value.limit(5).map do |item|
    #     item_data = {}
    #     item_data[:name] = item.name if item.respond_to?(:name)
    #     item_data[:title] = item.title if item.respond_to?(:title)
    #     item_data[:id] = item.id if item.respond_to?(:id)
    #     item_data[:type] = item.class.name if item.respond_to?(:class)
    #     item_data[:description] = item.description.to_s if item.respond_to?(:description) && item.description.present?
    #     item_data[:url] = item.url if item.respond_to?(:url) && item.url.present?
    #     item_data.compact
    #   end

    #   result = {
    #     type: 'relation',
    #     count: raw_value.count,
    #     items: items
    #   }
    #   result[:has_more] = true if raw_value.count > 5
    #   result.to_json
    # end

    # def process_object_value(raw_value)
    #   if raw_value.respond_to?(:as_json)
    #     begin
    #       json_data = raw_value.as_json
    #       cleaned_data = {}
    #       cleaned_data[:name] = json_data['name'] if json_data['name'].present?
    #       cleaned_data[:title] = json_data['title'] if json_data['title'].present?
    #       cleaned_data[:id] = json_data['id'] if json_data['id'].present?
    #       cleaned_data[:type] = raw_value.class.name
    #       cleaned_data[:description] = json_data['description'].to_s if json_data['description'].present?
    #       cleaned_data.compact.to_json
    #     rescue StandardError
    #       raw_value.to_s
    #     end
    #   elsif raw_value.respond_to?(:name)
    #     raw_value.name
    #   elsif raw_value.respond_to?(:title)
    #     raw_value.title
    #   else
    #     raw_value.to_s
    #   end
    # end
  end
end
