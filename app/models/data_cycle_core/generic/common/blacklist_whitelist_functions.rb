# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module BlacklistWhitelistFunctions
        def self.apply_blacklist(data, blacklist)
          return data if data.blank? || blacklist.blank?
          list = Array.wrap(blacklist)
          list.each { |path| data = reject_attribute(data, path) }
          data
        end

        def self.apply_whitelist(data, whitelist)
          return data if data.blank? || whitelist.blank?
          list = Array.wrap(whitelist)
          select_attributes(data, list)
        end

        # TODO: same as export/onlim function ... should be consolidated!!
        def self.reject_attribute(data, path)
          return data if path.blank?
          path = Array.wrap(path)
          key = path[0]
          leaf = path.size <= 1
          case data
          in Hash
            data[key] = reject_attribute(data[key], path[1..-1]) if data.key?(key)
            data.reject! { |k, _| k == key } if leaf
            data.compact.presence
          in Array
            data.map { |i| reject_attribute(i, path) }.compact.presence
          else
            data
          end
        end

        # TODO: same as export/onlim function ... should be consolidated!!
        def self.select_attributes(data, list)
          return data if list.blank? || data.blank?
          list.map! { |i| Array.wrap(i) }
          keys = list.map(&:first).uniq
          case data
          in Hash
            data
              .select { |k, _| k.in?(keys) || k.starts_with?('@') }
              .map { |k, v|
                next_level = list.select { |i| i[0] == k }.map { |i| i[1..-1].presence }.compact
                { k => select_attributes(v, next_level) }
              }.reduce(&:merge)
              &.compact
              &.presence
          in Array
            data.map { |i| select_attributes(i, list) }&.compact&.presence
          else
            nil
          end
        end
      end
    end
  end
end
