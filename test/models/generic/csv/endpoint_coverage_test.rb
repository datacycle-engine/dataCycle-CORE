# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'

module DataCycleCore
  module Generic
    module Csv
      # Coverage for the CSV endpoint. external_sources_path is stubbed to a temp
      # directory holding a fixture CSV, so the real file read path is exercised.
      class EndpointCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        test 'csv_categories yields rows and synthesizes parent categories' do
          Dir.mktmpdir do |dir|
            FileUtils.mkdir_p(File.join(dir, 'csv'))
            File.write(File.join(dir, 'csv', 'cats.csv'), "name;parent\nChild;Parent\nRoot;\n")

            DataCycleCore.stub(:external_sources_path, dir) do
              endpoint = DataCycleCore::Generic::Csv::Endpoint.new(options: { filename: 'cats.csv' })
              rows = endpoint.csv_categories(lang: :de).to_a

              # synthesized parent + the two data rows
              assert(rows.any? { |row| row['name'] == 'Parent' })
              assert(rows.any? { |row| row['name'] == 'Child' && row['parentId'].present? })
              assert(rows.any? { |row| row['name'] == 'Root' && row['parentId'].nil? })
            end
          end
        end
      end
    end
  end
end
