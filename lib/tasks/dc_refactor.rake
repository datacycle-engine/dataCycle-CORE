# frozen_string_literal: true

namespace :dc do
  namespace :refactor do
    namespace :classifications do
      desc 'move classification from one path to another z.B Inhaltstypen|Bild,Inhaltstypen|Assets|Bild'
      task :move_from_to, [:from_path, :to_path, :destroy_children] => [:environment] do |_, args|
        from_path = args.from_path&.split('|')&.map { |s| s.delete('"') }
        to_path = args.to_path&.split('|')&.map { |s| s.delete('"') }

        destroy_children = args.destroy_children == 'true'

        abort('ERROR: Missing from- or to_path') if from_path.blank? || to_path.blank?

        from_ca = DataCycleCore::ClassificationAlias.includes(:classification_alias_path).find_by(classification_alias_paths: { full_path_names: from_path.reverse })

        abort('ERROR: from ClassificationAlias not found') if from_ca.nil?

        abort('ERROR: error moving to new path') unless from_ca.move_to_path(to_path, destroy_children).is_a?(DataCycleCore::ClassificationAlias)
        puts('SUCCESS: successfully moved classification to new path')
      end
    end
  end
end
