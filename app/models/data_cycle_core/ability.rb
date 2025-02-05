# frozen_string_literal: true

module DataCycleCore
  class Ability
    include CanCan::Ability

    attr_accessor :user, :session

    def initialize(user, session = {})
      return unless user

      @user = user
      @session = session
      @user.ability = self

      DataCycleCore::Abilities::PermissionsList.add_abilities_for_user(self)
    end

    def concept_scheme(cs_name)
      @concept_scheme ||= Hash.new do |h, name|
        h[name] = begin
          DataCycleCore::ClassificationTreeLabel.find_by(name:)
        end
      end

      @concept_scheme[cs_name]
    end

    def can_attribute?(r_options = nil, key: nil, definition: {}, options: {}, content: nil, context: nil, scope: nil)
      @can_attribute ||= Hash.new do |h, opts|
        h[opts] = begin
          next can_attribute_group?(opts) if opts.attribute_group?
          next false if opts.context == :editor && !can_edit_attribute?(opts)

          next false unless can?(
            opts.scope.to_sym,
            DataCycleCore::DataAttribute.new(
              opts.key,
              opts.definition,
              opts.data_attribute_options,
              opts.content,
              opts.scope,
              opts.edit_scope
            )
          ) && (
            opts.content.nil? || opts.content.allowed_feature_attribute?(opts.attribute_name)
          )

          next false if opts.definition&.dig('type') == 'classification' &&
                        !DataCycleCore::ClassificationService.visible_classification_tree?(
                          concept_scheme(opts.definition['tree_label']),
                          opts.scope.to_s
                        ) && opts.attribute_name != 'universal_classifications'

          next false if opts.scope.to_s == 'update' && opts.definition&.dig('type') == 'linked' && opts.definition&.dig('link_direction') == 'inverse'

          true
        end
      end

      if r_options.nil?
        r_options = DataCycleCore::DataAttributeOptions.new(
          key:,
          definition:,
          parameters: { options: },
          content:,
          user:,
          context:,
          scope:
        )
      elsif !r_options.is_a?(DataCycleCore::DataAttributeOptions)
        raise ArgumentError, 'r_options must be a DataCycleCore::DataAttributeOptions'
      end

      @can_attribute[r_options]
    end

    private

    def can_attribute_group?(_options)
      true
    end

    def can_edit_attribute?(options)
      return false if options.virtual_attribute?

      if options.scope.to_s == 'edit'
        return false if options.computed_attribute? && !options.aggregated_attribute?
        return false if (options.aggregate_attribute? || options.overlay_attribute?) && !options.options_for_original_key.attribute_allowed?
      elsif options.computed_attribute?
        return false
      end

      return false if options.overlay_attribute? && !options.render_overlay_attribute?

      true
    end
  end
end
