# frozen_string_literal: true

module DataCycleCore
  module Feature
    class DuplicateCandidate < Base
      # reads the id pairs for dc:duplicates:merge_from_file from a csv/xlsx/ods file.
      #
      # the columns are located by their header, so the file may carry any number of further
      # columns (e.g. what a duplicate was matched by) in any order. rows above the header row
      # and sheets without the two id columns are ignored, so a legend sheet does no harm.
      #
      # a sheet that has them needs a status column as well. the status decides what is merged at
      # all: 'Treffer' keeps the content of the Original ID column, 'Mehrdeutig' leaves that to
      # the content score, every other status is skipped.
      class MergeSpreadsheet
        # raised when none of the sheets holds both id columns
        class MissingColumnsError < StandardError; end

        # raised when a sheet holds the id columns but no status column, which would merge every
        # row of it unclassified
        class MissingStatusColumnError < StandardError; end

        # accepted header labels, normalized by #normalize
        ORIGINAL_HEADERS = ['original id'].freeze
        DUPLICATE_HEADERS = ['duplikat id', 'duplicate id'].freeze

        # only this one label, so that no column of free text can end up deciding what is merged.
        # a file whose status is named differently raises instead of merging every row of it.
        STATUS_HEADERS = ['status'].freeze

        # 'Treffer' is a match that names its original, 'Mehrdeutig' one whose two contents are
        # the same thing without the file saying which of them to keep
        MATCH_STATUS = 'treffer'
        AMBIGUOUS_STATUS = 'mehrdeutig'
        MERGEABLE_STATUSES = [MATCH_STATUS, AMBIGUOUS_STATUS].freeze

        # a row holding both ids. +number+ counts from 1 within its sheet, as the file does,
        # so that an error can point at the line to fix.
        Pair = Struct.new(:sheet, :number, :original_id, :duplicate_id, :status) do
          # location in the file, for error messages
          def to_s
            "#{sheet}:#{number}"
          end

          # whether the row is merged at all. the status has to be one of MERGEABLE_STATUSES and
          # nothing else, so that a 'Kein Treffer' is not taken for a match. a pair carries no
          # status only when it was built by hand, since the reader requires the column.
          def mergeable?
            status.nil? || MERGEABLE_STATUSES.include?(normalized_status)
          end

          # whether #original_id names the content that has to survive. 'Mehrdeutig' does not,
          # there the content score decides (see MergePlan::Group#original). a pair without a
          # status names its original.
          def directed?
            status.nil? || normalized_status == MATCH_STATUS
          end

          private

          # the reader strips the cell already, this keeps a pair built by hand equivalent
          def normalized_status
            status.to_s.strip.downcase
          end
        end

        # :nodoc:
        def self.call(...)
          new(...).call
        end

        def initialize(path)
          @path = path
          @pairs = []
          @skipped_rows = []
          @skipped_status_rows = []
          @columns_found = false
        end

        # every row below the header that holds both ids and a mergeable status, in file order
        def call
          Roo::Spreadsheet.open(@path).each_with_pagename { |name, sheet| read_sheet(name, sheet) }

          raise MissingColumnsError, "no sheet in #{@path} has an #{ORIGINAL_HEADERS.first} and a #{DUPLICATE_HEADERS.first} column" if @columns_found.blank?

          @pairs
        end

        attr_reader :pairs

        # rows that carry only one of the two ids: the source files list contents without a
        # match as well, those rows are nothing to merge rather than an error
        attr_reader :skipped_rows

        # rows the status column excludes, each with the status it carries
        attr_reader :skipped_status_rows

        private

        def read_sheet(sheet_name, sheet)
          columns = nil

          # Roo yields the empty rows as well, starting at row 1, so the index is the line in
          # the sheet. an empty row arrives as [nil, nil, ...], which is not blank?
          sheet.each_with_index do |row, index|
            next if row.compact_blank.empty?

            if columns.nil?
              columns = columns_for(row)
              next if columns.nil?

              raise MissingStatusColumnError, "sheet '#{sheet_name}' of #{@path} has no #{STATUS_HEADERS.first} column" if columns[:status].nil?

              @columns_found = true
              next
            end

            add_row(sheet_name, index + 1, row, columns)
          end
        end

        # positions of the columns, or nil if this row is not the header row. the two id columns
        # identify it; the caller reports a header row that has no status column.
        def columns_for(row)
          headers = row.map { |cell| normalize(cell) }
          original = headers.index { |header| ORIGINAL_HEADERS.include?(header) }
          duplicate = headers.index { |header| DUPLICATE_HEADERS.include?(header) }
          return if original.nil? || duplicate.nil?

          { original:, duplicate:, status: headers.index { |header| STATUS_HEADERS.include?(header) } }
        end

        def add_row(sheet_name, number, row, columns)
          original_id = normalize_id(row[columns[:original]])
          duplicate_id = normalize_id(row[columns[:duplicate]])

          if original_id.blank? || duplicate_id.blank?
            @skipped_rows.push("#{sheet_name}:#{number}")
            return
          end

          status = columns[:status] && row[columns[:status]].to_s.strip
          pair = Pair.new(sheet_name, number, original_id, duplicate_id, status)

          if pair.mergeable?
            @pairs.push(pair)
          else
            @skipped_status_rows.push("#{pair} (#{status.presence || 'empty'})")
          end
        end

        # postgres returns uuids lowercased, so an uppercased cell would be found in the database
        # but never match its own group and be reported as a content that does not exist
        def normalize_id(cell)
          cell.to_s.strip.downcase
        end

        # headers are compared case insensitively and with '_' as a blank, so that both
        # 'Original ID' and 'original_id' name the same column
        def normalize(cell)
          cell.to_s.strip.downcase.tr('_', ' ').squeeze(' ')
        end
      end
    end
  end
end
