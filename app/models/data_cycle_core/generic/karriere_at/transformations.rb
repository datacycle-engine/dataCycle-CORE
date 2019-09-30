# frozen_string_literal: true

module DataCycleCore
  module Generic
    module KarriereAt
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.job_to_jobposting(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { s.dig('id', 'text') })
          .>> t(:add_field, 'name', ->(s) { s.dig('title', '#cdata-section') })
          .>> t(:add_field, 'description', ->(s) { s.dig('contentText', '#cdata-section').gsub(/\n/, '<br/>') })
          .>> t(:add_field, 'same_as', ->(s) { s.dig('staticUrl', '#cdata-section') })
          .>> t(:add_field, 'potential_action', ->(s) { { 'url' => s.dig('url', '#cdata-section') } })
          .>> t(:add_field, 'snippet', ->(s) { unescape_html(s.dig('snippet', '#cdata-section')) })
          .>> t(:add_field, 'date_posted', ->(s) { convert_to_time(s.dig('showDate', 'text')) })
          .>> t(:add_field, 'date_created', ->(s) { convert_to_time(s.dig('createDate', 'text')) })
          .>> t(:add_field, 'date_modified', ->(s) { convert_to_time(s.dig('changeDate', 'text')) })
          .>> t(:add_links, 'keywords', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('keywords', 'keyword')]&.compact&.flatten&.map { |item| "karriere.at - Keyword - #{item.dig('#cdata-section')}" }&.flatten || [] })
          .>> t(:add_links, 'employment_type', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('employmentTypes', 'employmentType')]&.compact&.flatten&.map { |item| "karriere.at - Employment Type - #{item.dig('id')}" }&.flatten || [] })
          .>> t(:add_links, 'job_fields', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('jobfields', 'jobfield')]&.compact&.flatten&.map { |item| "karriere.at - Job Field - #{item.dig('id')}" }&.flatten || [] })
          .>> t(:add_links, 'country', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('countries', 'country')]&.compact&.flatten&.map { |item| "karriere.at - Country - #{item.dig('#cdata-section')}" }&.flatten || [] })
          .>> t(:add_links, 'state', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('states', 'state')]&.compact&.flatten&.map { |item| "karriere.at - State - #{item.dig('#cdata-section')}" }&.flatten || [] })
          .>> t(:add_links, 'hiring_organization', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('company', 'children', 'id', 'text')]&.compact&.flatten&.map { |item| "Company:#{item}" }&.flatten || [] })
          .>> t(:add_links, 'job_location', DataCycleCore::Thing, external_source_id, ->(s) { [parse_place_key(s)].compact })
          .>> t(:reject_keys, ['id', 'title', 'sharing', 'isPdf', 'geo', 'company', 'jobLevel'])
          .>> t(:compact)
          .>> t(:strip_all)
        end

        def self.job_to_organization
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { ['Company:', s.dig('id', 'text')].join('') })
          .>> t(:add_field, 'name', ->(s) { s.dig('name', '#cdata-section') })
          .>> t(:reject_keys, ['id'])
          .>> t(:compact)
          .>> t(:strip_all)
        end

        def self.job_to_place
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { parse_place_key(s) })
          .>> t(:add_field, 'name', ->(s) { s.dig('location', '#cdata-section') })
          .>> t(:add_field, 'latitude', ->(s) { parse_float(s.dig('geo', 'lat', 'text')) })
          .>> t(:add_field, 'longitude', ->(s) { parse_float(s.dig('geo', 'lng', 'text')) })
          .>> t(:reject_keys, ['location'])
          .>> t(:location)
          .>> t(:reject_keys, ['id'])
          .>> t(:compact)
          .>> t(:strip_all)
        end

        def self.convert_to_time(epoch_string)
          return if epoch_string.blank?
          Time.at(epoch_string.to_i).in_time_zone
        end

        def self.parse_float(string)
          return if string == '0'
          string&.to_f
        end

        def self.parse_place_key(s)
          name = s.dig('location', '#cdata-section').squish
          lat = parse_float(s.dig('geo', 'lat', 'text'))
          lon = parse_float(s.dig('geo', 'lng', 'text'))
          return if name.blank? && lat.blank? && lon.blank?
          ['JobLocation:', name, lat.to_s, lon.to_s].join(' ').squish
        end

        def self.unescape_html(string)
          Nokogiri::HTML.fragment(string)&.to_s&.downcase
        end
      end
    end
  end
end
