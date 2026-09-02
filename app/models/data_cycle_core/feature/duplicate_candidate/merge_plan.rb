# frozen_string_literal: true

module DataCycleCore
  module Feature
    class DuplicateCandidate < Base
      # turns the id pairs of a merge file into the groups that are merged into one content
      # each. pairs are transitive for the grouping: 'a-b' plus 'a-c' and 'a-b' plus 'b-c' both
      # end up as the single group {a, b, c}.
      #
      # a group keeps the content its directed rows agree on, which is the one none of them
      # lists as a duplicate. where they leave no single candidate - because they contradict
      # each other or because the file marks them 'Mehrdeutig' -
      # DuplicateCandidate.original_for_merge decides by content score.
      #
      # the whole plan is validated before the first merge, so that a broken file cannot leave
      # half of it merged.
      class MergePlan
        # one group of contents that are merged into #original
        class Group
          # a duplicate that did not go through: +reason+ is :locked when a ContentLock blocked
          # part of the merge, :refused when the core rejected the pair outright
          Failure = Struct.new(:duplicate, :reason, :message)

          attr_reader :ids, :pairs, :contents

          # +ids+ every id of the group, +pairs+ the rows it was built from, +contents+ the
          # contents that exist for +ids+
          def initialize(ids:, pairs:, contents:)
            @ids = ids
            @pairs = pairs
            @contents = contents
          end

          # the content that survives the merge: the one the file's directed rows name, the
          # highest content score where they name none
          def original
            @original ||= original_from_file || DataCycleCore::Feature::DuplicateCandidate.original_for_merge(contents)
          end

          # :nodoc:
          def duplicates
            contents - [original]
          end

          # :nodoc:
          def valid?
            errors.blank?
          end

          # merges every duplicate into #original, returns the failures for the caller to log
          # and reschedule. only call it on a valid? group.
          #
          # merging several duplicates into the same original in a row needs no refresh in
          # between: the merge version written for each of them reloads the original (see
          # Content::DataHash#set_data_hash), so Merge sees the links the previous merge moved
          # over and leaves them where they are instead of moving a second one onto them.
          def merge!(current_user: nil)
            duplicates.each_with_object([]) do |duplicate, failures|
              failures.push(Failure.new(duplicate, :refused)) unless original.merge_with_duplicate_and_version(duplicate, current_user:, async: false)
            rescue DataCycleCore::Feature::DuplicateCandidate::Merge::LockedContentsError => e
              failures.push(Failure.new(duplicate, :locked, e.message))
            end
          end

          # everything that keeps this group from being merged. all of them are collected, so
          # that one run lists every problem of the file instead of only the first one.
          def errors
            @errors ||= self_reference_errors + invalid_id_errors + missing_content_errors + template_errors
          end

          # what the group merges, with the rows of the file it came from
          def to_s
            "#{original&.id} <- #{duplicates.map(&:id).join(', ')} (#{pairs.map(&:to_s).uniq.join(', ')})"
          end

          private

          # the content the file names as the original: the single id that the directed rows list
          # as an original and never as a duplicate. that covers a group of more than two
          # contents as well, both the star ('a-b' plus 'a-c' name a) and the chain ('a-b' plus
          # 'b-c' name a).
          #
          # nil once the directed rows leave no single candidate: none of them is directed
          # (every row 'Mehrdeutig'), they contradict each other ('a-b' plus 'b-a'), or they name
          # two originals for the same group ('a-b' plus 'c-b'). nil as well for a named original
          # that does not exist - #errors reports that group anyway.
          def original_from_file
            directed = pairs.select(&:directed?)
            candidates = directed.map(&:original_id).uniq - directed.map(&:duplicate_id)
            return unless candidates.size == 1

            contents.find { |content| content.id == candidates.first }
          end

          def self_reference_errors
            pairs
              .select { |pair| pair.original_id == pair.duplicate_id }
              .map { |pair| "#{pair}: #{pair.original_id} references itself" }
          end

          def invalid_id_errors
            ids.reject(&:uuid?).map { |id| "#{rows_for(id)}: '#{id}' is not a valid id" }
          end

          def missing_content_errors
            (ids.select(&:uuid?) - contents.map(&:id)).map { |id| "#{rows_for(id)}: content #{id} does not exist" }
          end

          # a merge moves the links of the duplicate over to the original, which only makes
          # sense as long as both are of the same template
          def template_errors
            template_names = contents.map(&:template_name).uniq
            return [] if template_names.size <= 1

            ["#{pairs.map(&:to_s).uniq.join(', ')}: group #{ids.join(', ')} mixes the templates #{template_names.join(', ')}"]
          end

          # the rows an id appeared in, to point at the file instead of at the id alone
          def rows_for(id)
            pairs.select { |pair| [pair.original_id, pair.duplicate_id].include?(id) }.map(&:to_s).uniq.join(', ')
          end
        end

        # :nodoc:
        def self.call(...)
          new(...).call
        end

        def initialize(pairs)
          @pairs = pairs
        end

        # groups the pairs and loads their contents, returns the plan itself
        def call
          # the groups are rebuilt below, so a memoized error list must not survive
          @errors = nil

          id_groups = build_id_groups
          contents = contents_by_id(id_groups.flatten)

          @groups = id_groups.map do |ids|
            Group.new(
              ids:,
              pairs: @pairs.select { |pair| ids.include?(pair.original_id) || ids.include?(pair.duplicate_id) },
              contents: ids.filter_map { |id| contents[id] }
            )
          end

          self
        end

        # every group of the file, mergeable or not
        def groups
          @groups || call.groups
        end

        # :nodoc:
        def valid_groups
          groups.select(&:valid?)
        end

        # :nodoc:
        def invalid_groups
          groups.reject(&:valid?)
        end

        # :nodoc:
        def errors
          @errors ||= groups.flat_map(&:errors)
        end

        private

        # every pair joins the groups of its two ids, which makes the grouping transitive
        def build_id_groups
          groups = []

          @pairs.each do |pair|
            ids = [pair.original_id, pair.duplicate_id].uniq
            overlapping, groups = groups.partition { |group| group.intersect?(ids) }
            groups.push(overlapping.flatten.union(ids))
          end

          groups
        end

        def contents_by_id(ids)
          DataCycleCore::Thing.where(id: ids.select(&:uuid?)).index_by(&:id)
        end
      end
    end
  end
end
