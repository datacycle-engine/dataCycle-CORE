# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Export
    class TextFileTest < ActiveSupport::TestCase
      test 'run TextFile refresh task' do
        external_system = DataCycleCore::ExternalSystem.find_by(name: 'Local-Text-File')
        external_system.refresh
      end
    end
  end
end
