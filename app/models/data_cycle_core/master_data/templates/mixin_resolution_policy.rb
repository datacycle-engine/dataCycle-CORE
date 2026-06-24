# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      # Domain service encapsulating mixin resolution selection and ordering logic:
      #
      # 1. Specificity defines the primary scope of a mixin.
      # 2. Path depth ensures that, among mixins of equal specificity, the one defined in a deeper folder structure is chosen, allowing for more granular overrides.
      # 3. Template path reverse index allows for a final tiebreaker based on the order of template_paths, giving precedence to mixins found in earlier paths.
      module MixinResolutionPolicy
        # Selects the best candidate from the set of generically scoped mixins, optionally including content-set scoped mixins.
        # @param mixins [Array<Hash>] mixins to select from
        # @param include_content_set [Symbol, nil] the content set to match for selection, optional
        # @return [Hash, nil] the best candidate mixin, or nil if no suitable mixin is found
        def select_best_candidate(mixins, include_content_set: nil)
          mixins
            &.select { |mixin| mixin[:set].nil? || mixin[:set] == include_content_set }
            &.min_by { |mixin| negative_resolution_order(mixin) }
        end

        # Sorts mixins from best to worst candidate for mixin resolution.
        # @param mixins [Array<Hash>] mixins to sort
        # @return [Array<Hash>] sorted mixins from best to worst candidate
        def sort_descending!(mixins)
          mixins
            &.sort_by! { |mixin| negative_resolution_order(mixin) }
        end

        private

        # Computes a tuple for mixin resolution ordering, where higher specificity and deeper path yield a "lower" value.
        # This is for sorting in descending order: not needing to reverse the sorting, which works in ascending order.
        # @param mixin [Hash] the mixin to compute the resolution order for: must include :specificity, :relative_path, and :template_paths_reverse_index keys
        # @return [Array<Integer>] the negative resolution order tuple
        def negative_resolution_order(mixin)
          [
            -mixin[:specificity].to_i,
            -mixin[:relative_path].to_s.count(File::SEPARATOR),
            mixin[:template_paths_reverse_index].to_i
          ]
        end
      end
    end
  end
end
