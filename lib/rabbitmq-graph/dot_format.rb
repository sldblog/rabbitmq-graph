# frozen_string_literal: true

require 'set'

# Presents a RabbitMQ topology in graphviz's .dot format
class DotFormat
  def initialize(topology:, show_entities: true, label_detail: %i[actions])
    @topology = topology
    @show_entities = show_entities
    @label_detail = label_detail
  end

  def present
    <<-GRAPH
    digraph G {
      #{render_application_subgraph}
      #{render_entity_subgraph}
      #{message_edges.join("\n")}
    }
    GRAPH
  end

  private

  attr_reader :topology, :show_entities, :label_detail

  def render_application_subgraph
    <<-APPS
      subgraph Apps {
        node [shape=oval fillcolor=yellow style=filled]
        #{application_nodes.join("\n")}
      }
    APPS
  end

  def render_entity_subgraph
    return '' unless show_entities

    <<-ENTITIES
      subgraph Entities {
        node [shape=box fillcolor=turquoise style=filled]
        #{entity_nodes.join("\n")}
      }
    ENTITIES
  end

  def application_nodes
    applications = {}
    topology.each do |route|
      applications[route.source_app] ||= Set.new
      applications[route.source_app] << 'fillcolor="red"' if route.missing_source?

      applications[route.target_app] ||= Set.new
      applications[route.target_app] << 'fillcolor="red"' if route.missing_target?
      applications[route.target_app] << 'fillcolor="orange"' if route.default_consumer_tag?
    end
    applications.map { |name, properties| %("#{name}" [#{properties.to_a.join(' ')}]) }.sort
  end

  def entity_nodes
    entities = topology.map(&:entity).sort.uniq
    entities.map { |entity| %("#{entity}") }
  end

  def message_edges
    topology.map { |route| %(#{route_path(route)} [#{route_properties(route)}]) }.uniq
  end

  def route_path(route)
    path = []
    path << route.source_app
    path << route.entity if show_entities
    path << route.target_app
    path.map { |text| %("#{text}") }.join('->')
  end

  def route_properties(route)
    label = label_detail.select { |detail| route.respond_to?(detail) }
                        .map { |detail| route.public_send(detail) }
                        .flatten.join('.')
    properties = []
    properties << %(label="#{label}")
    properties << %(color="red") if route.missing_source? || route.missing_target?
    properties.join(' ')
  end
end
