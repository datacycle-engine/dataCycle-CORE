# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

module DataCycleCore
  class DuplicateCandidateMergeSpreadsheetTest < DataCycleCore::TestCases::ActiveSupportTestCase
    ORIGINAL_ID = '6a2ee0a2-0c8f-4b0e-9c96-2e2a0a2f6f01'
    DUPLICATE_ID = '6a2ee0a2-0c8f-4b0e-9c96-2e2a0a2f6f02'
    THIRD_ID = '6a2ee0a2-0c8f-4b0e-9c96-2e2a0a2f6f03'

    def subject
      DataCycleCore::Feature::DuplicateCandidate::MergeSpreadsheet
    end

    test 'reads the id pairs of a file with the german headers' do
      pairs = spreadsheet_for(<<~CSV).pairs
        Original ID,Duplikat ID,Status,Gematcht über
        #{ORIGINAL_ID},#{DUPLICATE_ID},Treffer,name
      CSV

      assert_equal 1, pairs.size
      assert_equal ORIGINAL_ID, pairs.first.original_id
      assert_equal DUPLICATE_ID, pairs.first.duplicate_id
      assert_equal 2, pairs.first.number
    end

    test 'reads the status column and tells a Treffer apart from a Mehrdeutig row' do
      pairs = spreadsheet_for(<<~CSV).pairs
        Original ID,Duplikat ID,Status
        #{ORIGINAL_ID},#{DUPLICATE_ID},Treffer
        #{THIRD_ID},#{ORIGINAL_ID},Mehrdeutig
      CSV

      assert_equal ['Treffer', 'Mehrdeutig'], pairs.map(&:status)
      assert_predicate pairs.first, :directed?
      assert_not_predicate pairs.second, :directed?
    end

    # without the column nothing classifies the rows, and merging all of them unclassified is
    # what the status is there to prevent
    test 'raises when the sheet has the id columns but no status column' do
      error = assert_raises(subject::MissingStatusColumnError) do
        spreadsheet_for(<<~CSV)
          Original ID,Duplikat ID,Gematcht über
          #{ORIGINAL_ID},#{DUPLICATE_ID},name
        CSV
      end

      assert_includes error.message, 'no status column'
    end

    # a row of the BVT file that nobody classified is not a confirmed duplicate, and a merge
    # cannot be undone
    test 'skips a row with an empty status cell' do
      spreadsheet = spreadsheet_for(<<~CSV)
        Original ID,Duplikat ID,Status
        #{ORIGINAL_ID},#{DUPLICATE_ID},
      CSV

      assert_empty spreadsheet.pairs
      assert_equal ['default:2 (empty)'], spreadsheet.skipped_status_rows
    end

    # 'Kein Treffer' contains 'Treffer', so a substring match would have merged it in the
    # direction the file names
    test 'skips a row whose status is neither Treffer nor Mehrdeutig' do
      spreadsheet = spreadsheet_for(<<~CSV)
        Original ID,Duplikat ID,Status
        #{ORIGINAL_ID},#{DUPLICATE_ID},Kein Treffer
        #{THIRD_ID},#{ORIGINAL_ID},prüfen
      CSV

      assert_empty spreadsheet.pairs
      assert_equal ['default:2 (Kein Treffer)', 'default:3 (prüfen)'], spreadsheet.skipped_status_rows
    end

    test 'accepts a status in any case and with surrounding blanks' do
      spreadsheet = spreadsheet_for(<<~CSV)
        Original ID,Duplikat ID,Status
        #{ORIGINAL_ID},#{DUPLICATE_ID},  treffer
        #{THIRD_ID},#{ORIGINAL_ID},MEHRDEUTIG
      CSV

      assert_empty spreadsheet.skipped_status_rows
      assert_equal [true, false], spreadsheet.pairs.map(&:directed?)
    end

    # excel exports and hand-edited cells carry uppercased ids, which postgres finds but the
    # plan then matches against the lowercased id it returns
    test 'downcases the ids so they match what the database returns' do
      pairs = spreadsheet_for(<<~CSV).pairs
        Original ID,Duplikat ID,Status
        #{ORIGINAL_ID.upcase},#{DUPLICATE_ID.upcase},Treffer
      CSV

      assert_equal([[ORIGINAL_ID, DUPLICATE_ID]], pairs.map { |pair| [pair.original_id, pair.duplicate_id] })
    end

    test 'accepts snake_case headers in any column order' do
      pairs = spreadsheet_for(<<~CSV).pairs
        Gematcht über,duplicate_id,Status,original_id
        name,#{DUPLICATE_ID},Treffer,#{ORIGINAL_ID}
      CSV

      assert_equal([[ORIGINAL_ID, DUPLICATE_ID]], pairs.map { |pair| [pair.original_id, pair.duplicate_id] })
    end

    test 'ignores the rows above the header row' do
      pairs = spreadsheet_for(<<~CSV).pairs
        Zusammenführung BVT
        Original ID,Duplikat ID,Status
        #{ORIGINAL_ID},#{DUPLICATE_ID},Treffer
      CSV

      assert_equal 1, pairs.size
      assert_equal 3, pairs.first.number
    end

    test 'skips rows that carry only one of the two ids' do
      spreadsheet = spreadsheet_for(<<~CSV)
        Original ID,Duplikat ID,Status
        #{ORIGINAL_ID},,Treffer
        #{ORIGINAL_ID},#{DUPLICATE_ID},Treffer
      CSV

      assert_equal 1, spreadsheet.pairs.size
      assert_equal 1, spreadsheet.skipped_rows.size
      assert spreadsheet.skipped_rows.first.end_with?(':2'), "expected the skipped row to point at line 2, got #{spreadsheet.skipped_rows.first}"
    end

    test 'reads an xlsx file and reports the line in the sheet, not the iteration index' do
      sheets = {
        'Legende' => [['Gematcht über', 'Bedeutung'], ['name', 'gleicher Name']],
        'Duplikate' => [
          [],
          ['Zusammenführung BVT'],
          ['Original ID', 'Duplikat ID', 'Status', 'Gematcht über'],
          [ORIGINAL_ID, DUPLICATE_ID, 'Treffer', 'name'],
          [],
          [THIRD_ID, ORIGINAL_ID, 'Treffer', 'geo']
        ]
      }

      with_xlsx(sheets) do |path|
        spreadsheet = subject.new(path)
        pairs = spreadsheet.call

        assert_equal([[ORIGINAL_ID, DUPLICATE_ID], [THIRD_ID, ORIGINAL_ID]], pairs.map { |pair| [pair.original_id, pair.duplicate_id] })
        assert_equal [4, 6], pairs.map(&:number)
        assert_equal ['Duplikate'], pairs.map(&:sheet).uniq
        assert_empty spreadsheet.skipped_rows
      end
    end

    test 'raises when no sheet has both id columns' do
      assert_raises(subject::MissingColumnsError) do
        spreadsheet_for(<<~CSV)
          Name,Gematcht über
          Bäckerei Mangold,name
        CSV
      end
    end

    private

    def spreadsheet_for(csv)
      with_csv(csv) do |path|
        spreadsheet = subject.new(path)
        spreadsheet.call
        spreadsheet
      end
    end

    # +sheets+ as { sheet name => rows }, an empty array being an empty row
    def with_xlsx(sheets)
      file = Tempfile.new(['merge_duplicates', '.xlsx'])
      file.close

      package = Axlsx::Package.new
      sheets.each do |name, rows|
        package.workbook.add_worksheet(name:) { |sheet| rows.each { |row| sheet.add_row(row) } }
      end
      package.serialize(file.path)

      yield file.path
    ensure
      file&.unlink
    end

    def with_csv(content)
      file = Tempfile.new(['merge_duplicates', '.csv'])
      file.write(content)
      file.close

      yield file.path
    ensure
      file&.unlink
    end
  end
end
