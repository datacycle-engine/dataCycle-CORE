# frozen_string_literal: true

module DataCycleCore
  module Releasable
    extend ActiveSupport::Concern

    def merge_release(data_hash, release_hash)
      data_iterator_merge(data_hash, release_hash)
    end

    def extract_release(data_hash, full)
      data_iterator_split(data_hash, full)
    end

    def data_iterator_merge(data_hash, release_hash)
      return data_hash if release_hash.blank?
      release_hash.each_key do |key|
        data_hash[key] = merge_data(data_hash[key], release_hash[key])
      end
      data_hash
    end

    def data_iterator_split(original_hash, full)
      data_hash = {}
      release_hash = {}
      original_hash.each_key do |key|
        data_hash[key], release_hash[key] = split_data(original_hash[key], full)
        release_hash[key] = nil if release_hash[key].blank?
      end
      return data_hash.compact, release_hash.compact
    end

    def merge_data(data_value, release_data)
      return data_value if release_data.blank?
      return data_iterator_merge(data_value, release_data) if data_value.is_a?(::Hash) # --> embedded data
      return release_data.merge({ 'value' => data_value }) unless data_value.is_a?(::Array) # --> single value
      return release_data.merge({ 'value' => data_value }) unless data_value.first.is_a?(::Hash) # --> Array of values

      return_data = []
      data_value.each_index do |index|
        return_data.push(data_iterator_merge(data_value[index], release_data[index]))
      end
      return_data
    end

    def split_data(original, full)
      return original['value'], { 'release_id' => original.try(:[], 'release_id'), 'release_comment' => original.try(:[], 'release_comment') } if release_data?(original)

      if original.is_a?(::Hash) # --> embedded data
        data_iterator_split(original, full)
      elsif original.is_a?(::Array)
        return original, nil if !original.first.is_a?(::Hash) || !full # --> Array of values
        return_data = []
        return_release = []
        original.each do |item|
          data_item, release_item = data_iterator_split(item, full)
          return_data.push(data_item)
          return_release.push(release_item)
        end
        return return_data, return_release
      else
        return original, nil # --> single value
      end
    end

    def global_release(global_release_hash)
      ids = []
      flat_hash = flatten_hash(global_release_hash)
      flat_hash.map { |key, value| ids.push(value) if key[/release_id\z/] }
      max_release_status_id(ids.uniq)
    end

    def flatten_hash(data_hash, prefix = nil)
      result = {}
      data_hash = data_hash.as_json

      if data_hash.is_a?(::Hash)
        data_hash.map do |hash_key, hash_value|
          hash_key = "#{prefix}.#{hash_key}" if prefix.present?
          result.merge!([::Hash, ::Array].include?(hash_value.class) ? flatten_hash(hash_value, hash_key) : { hash_key => hash_value })
        end
      end

      if data_hash.is_a?(::Array)
        data_hash.uniq.each_with_index do |item, index|
          index = "#{prefix}.#{index}" if prefix.present?
          result.merge!([::Hash, ::Array].include?(item.class) ? flatten_hash(item, index) : { index => item })
        end
      end

      result
    end

    def release_data?(value)
      return false unless value.is_a?(::Hash)
      return true if value.key?('value') || value.key?('release_id') || value.key?('release_comment')
      false
    end

    # functions to define the release logic
    def max_release_status_id(ids)
      releases = Release.order(release_code: :desc).find_by(id: ids)
      releases.nil? ? release_id_released : releases.id # nil defined as "freigegeben"
    end

    # release_code 0 defined as "freigegeben"
    def release_id_released
      Release.find_by(release_code: 0).id
    end

    # utility functions
    def release_status
      Release.find(release_id)
    end

    def release_status_code
      Release.find(release_id) ? Release.find(release_id).release_code : nil
    end
  end
end