# frozen_string_literal: true

# Test-only transformation factory for the import-pipeline coverage tests.
#
# Production references transformation modules by their constant name via the
# importer config (`transformations:` + `transformation:`); each factory method
# takes an optional external_source_id and returns a transformation lambda that
# is applied to a raw-data hash. This is a minimal, autoloadable stand-in.
module DummyCoverageTransformations
  # @param _external_source_id [String, nil]
  # @return [Proc] a pass-through transformation applied to a raw-data hash
  def self.passthrough(_external_source_id = nil)
    ->(data) { data }
  end
end
