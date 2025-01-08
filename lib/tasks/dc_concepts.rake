# frozen_string_literal: true

namespace :dc do
  namespace :concepts do
    desc 'import new concepts from classifications.yml'
    task :import, [:verbose] => :environment do |_, _args|
      before_import = Time.zone.now
      puts "importing new concepts\n"
      importer = DataCycleCore::MasterData::Concepts::ConceptImporter.new
      importer.import
      importer.render_errors

      importer.valid? ? puts("[done] ... looks good (Duration: #{(Time.zone.now - before_import).round} sec, #{importer.counts[:concept_schemes]}/#{importer.counts[:concepts]}/#{importer.counts[:concept_mappings]})") : exit(-1)
    end
  end
end
