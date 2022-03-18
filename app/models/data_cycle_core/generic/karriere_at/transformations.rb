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
          .>> t(:add_field, 'external_key', ->(s) { s.dig('id').to_s })
          .>> t(:add_field, 'name', ->(s) { s.dig('title') })
          .>> t(:add_field, 'description', ->(s) { s.dig('contentText')&.gsub(/\n/, '<br/>') })
          .>> t(:add_field, 'same_as', ->(s) { s.dig('staticUrl') })
          .>> t(:add_field, 'potential_action', ->(s) { { 'action_url' => s.dig('url') } })
          .>> t(:add_field, 'snippet', ->(s) { unescape_html(s.dig('snippet')) })
          .>> t(:add_field, 'date_posted', ->(s) { s.dig('showDate') })
          .>> t(:add_field, 'date_created', ->(s) { s.dig('createDate') })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('changeDate') })
          .>> t(:add_links, 'keywords', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('keywords')]&.compact&.flatten&.map { |item| "karriere.at - Keyword - #{item}" }&.flatten || [] })
          .>> t(:add_links, 'employment_type', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('employmentTypes')]&.compact&.flatten&.map { |item| "karriere.at - Employment Type - #{item.dig('id')}" }&.flatten || [] })
          .>> t(:add_links, 'job_fields', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('jobFields')]&.compact&.flatten&.map { |item| "karriere.at - Job Field - #{item.dig('id')}" }&.flatten || [] })
          .>> t(:add_links, 'country', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('countries')]&.compact&.flatten&.map { |item| "karriere.at - Country - #{item.dig('label')}" }&.flatten || [] })
          .>> t(:add_links, 'state', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('states')]&.compact&.flatten&.map { |item| "karriere.at - State - #{item.dig('label')}" }&.flatten || [] })
          .>> t(:add_links, 'hiring_organization', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('company', 'id')]&.compact&.flatten&.map { |item| "Company:#{item}" }&.flatten || [] })
          .>> t(:add_links, 'job_location', DataCycleCore::Thing, external_source_id, ->(s) { [parse_place_key(s)].compact })
          .>> t(:reject_keys, ['id', 'title', 'sharing', 'isPdf', 'geo', 'company', 'jobLevels'])
          .>> t(:strip_all)
        end

        def self.job_to_organization
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { ['Company:', s.dig('id')].join('') })
          .>> t(:add_field, 'name', ->(s) { s.dig('name') })
          .>> t(:add_field, 'slug', ->(s) { s.dig('slug') })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.job_to_place
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { parse_place_key(s) })
          .>> t(:add_field, 'name', ->(s) { s.dig('location') })
          .>> t(:add_field, 'latitude', ->(s) { parse_float(s.dig('geo', 'lat')) })
          .>> t(:add_field, 'longitude', ->(s) { parse_float(s.dig('geo', 'lng')) })
          .>> t(:reject_keys, ['location'])
          .>> t(:location)
          .>> t(:reject_keys, ['id', 'meta', 'states', 'countries', 'contentText', 'snippet', 'keywords', 'employmentTypes', 'jobFields', 'jobLevels'])
          .>> t(:strip_all)
        end

        def self.parse_float(string)
          return if string == '0'
          string&.to_f
        end

        def self.parse_place_key(s)
          name = s.dig('location').squish
          lat = parse_float(s.dig('geo', 'lat'))
          lon = parse_float(s.dig('geo', 'lng'))
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
