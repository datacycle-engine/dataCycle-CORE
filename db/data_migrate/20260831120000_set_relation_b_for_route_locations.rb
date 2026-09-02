# frozen_string_literal: true

# [#51121] Tour's start_location/end_location gained an :inverse_of:, so a route location shared by
# several tours can name the ones that start and end there (datacycle-schema-legacy,
# places/mixins/route_location_link.yml on POI and Örtlichkeit, api-disabled there; PIA turns the
# api on so the relation can be filtered on).
#
# content_contents.relation_b is written from the forward property's :inverse_of: when a tour is
# saved, and Content#load_relation filters a linked read on relation_a *and* relation_b. Every row
# written before that change carries relation_b IS NULL, so declaring :inverse_of: start_location_of
# on Tour stops those rows matching in *both* directions - the tour loses its own start location too.
# This backfills relation_b so neither read has to wait for every tour to be saved again.
#
# The template name and the inverse name are read from the imported ThingTemplates rather than
# hardcoded. data-cycle-core and datacycle-schema-legacy carry independent submodule pointers, so a
# project can deploy this core while its Tour still declares no :inverse_of:, and the newer data
# definitions name the template Trail (datacycle-schema-tourism, places/trail.yml) and declare no
# inverse at all. A hardcoded 'Tour' => 'start_location_of' would write a relation_b those templates
# never ask for and break the forward read in exactly the way this migration exists to prevent.
# dc:update imports the configs before it runs the data migrations, so the schema read here is
# already the new one and the value written is the one load_relation will filter on. A template that
# declares the inverse later needs a backfill of its own - data_migrations records this run as done.
#
# Inline rather than through RunTaskJob, for that same ordering reason: once the configs are
# imported the templates already ask for the new relation_b, and a queued job would leave every tour
# without a start and end location until a worker picked it up.
class SetRelationBForRouteLocations < ActiveRecord::Migration[8.0]
  RELATIONS = ['start_location', 'end_location'].freeze

  def up
    inverses = declared_inverses
    return say("no template declares an :inverse_of: for #{RELATIONS.join(' or ')}") if inverses.blank?

    lift_statement_timeout

    inverses.each { |template_name, relation, inverse_of| move_relation_b(relation, template_name, inverse_of) }
  end

  # Clears the column for every entity template instead of for the ones that currently declare an
  # :inverse_of:, because reverting datacycle-schema-legacy re-imports a Tour without one and would
  # otherwise leave the rows behind - the state that breaks the forward read. For that reason a
  # rollback has to run this before the old templates are imported, or after them by hand.
  #
  # content_content_links follows relation_b through update_content_content_links_trigger, so the
  # inverse links go with it.
  def down
    lift_statement_timeout

    RELATIONS.each { |relation| move_relation_b(relation, nil, nil) }
  end

  private

  def declared_inverses
    DataCycleCore::ThingTemplate.all.flat_map do |thing_template|
      RELATIONS.filter_map do |relation|
        inverse_of = thing_template.schema&.dig('properties', relation, 'inverse_of')
        next if inverse_of.blank?

        [thing_template.template_name, relation, inverse_of]
      end
    end
  end

  # relation_a is passed through unchanged, only relation_b moves. The task updates content_contents
  # and content_content_histories in one pass, and covers every entity template when template_name
  # is nil.
  def move_relation_b(relation, template_name, relation_b)
    DataCycleCore::RakeTaskService.invoke(
      'dc:templates:migrations:embedded_relations',
      [relation, relation, template_name, relation_b]
    )
  end

  # config/database.yml caps statements at 1min and the task raises no timeout of its own, while
  # content_content_histories holds a row per tour version.
  def lift_statement_timeout
    ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
  end
end
