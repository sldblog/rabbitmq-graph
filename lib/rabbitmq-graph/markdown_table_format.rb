# frozen_string_literal: true

# Presents a RabbitMQ topology in a GitHub-flavoured Markdown table
class MarkdownTableFormat
  def initialize(topology:)
    @topology = topology
  end

  def present
    no_consumer_routes = topology.select(&:missing_target?)
    no_binding_routes = topology.select(&:missing_source?)
    default_tag_routes = topology.select(&:default_consumer_tag?)
    connected_routes = topology.reject { |r| r.missing_source? || r.missing_target? || r.default_consumer_tag? }

    lines = []
    lines.concat(route_table('Routes without consumers', no_consumer_routes))
    lines.concat(route_table('Routes without publisher bindings', no_binding_routes))
    lines.concat(route_table('Routes with default consumer names', default_tag_routes))
    lines.concat(route_table('Named, connected routes', connected_routes))
    lines.join("\n")
  end

  private

  attr_reader :topology

  def route_table(title, routes)
    return [] if routes.empty?
    lines = []
    lines << ''
    lines << "# #{title}"
    lines << ''
    lines << '| Publisher application | Consumer application | Entity | Actions | Queue |'
    lines << '| --- | --- | --- | --- | --- |'
    lines.concat(routes.map { |route| route_line(route) }.uniq)
  end

  def route_line(route)
    columns = []
    columns << route.source_app
    columns << route.target_app
    columns << route.entity
    columns << route.actions.join('.')
    columns << route.queue_name
    '| ' + columns.join(' | ') + ' |'
  end
end
