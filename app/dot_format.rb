# frozen_string_literal: true

class DotFormat
  APPLICATION_ONLY_LEVEL = 1
  HIGHEST_LEVEL = 2

  def initialize(topology:,
                 graph_level: ENV.fetch('LEVEL', HIGHEST_LEVEL).to_i,
                 edge_level: ENV.fetch('EDGE_LEVEL', HIGHEST_LEVEL).to_i)
    @topology = topology
    @graph_level = graph_level
    @edge_level = edge_level
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

  attr_reader :topology, :graph_level, :edge_level

  def render_application_subgraph
    <<-APPS
      subgraph Apps {
        node [shape=hexagon fillcolor=yellow style=filled]
        #{application_nodes.join("\n")}
      }
    APPS
  end

  def render_entity_subgraph
    <<-ENTITIES
      subgraph Entities {
        node [shape=box fillcolor=turquoise style=filled]
        #{entity_nodes.join("\n")}
      }
    ENTITIES
  end

  def application_nodes
    applications = topology.map { |route| [route[:from_app], route[:to_app]] }.flatten.sort.uniq
    applications.inject([]) do |list, app|
      label = %("#{app}")
      label += ' [fillcolor=red]' if app.empty?
      list << label
    end
  end

  def entity_nodes
    return [] unless graph_level > APPLICATION_ONLY_LEVEL
    entities = topology.map { |route| route[:entity] }.sort.uniq
    entities.map { |entity| %("#{entity}") }
  end

  def message_edges
    topology.map { |route| %(#{route_path(route)} [#{route_properties(route)}]) }.uniq
  end

  def route_path(route)
    path = []
    path << route[:from_app]
    path << route[:entity] if graph_level > APPLICATION_ONLY_LEVEL
    path << route[:to_app]
    path.map { |text| %("#{text}") }.join('->')
  end

  def route_properties(route)
    qualifier = route[:key][edge_level..-1]&.join('.').to_s
    properties = []
    properties << %(label="#{qualifier}")
    properties << %(color="red") if route[:to_app].to_s.empty?
    properties.join(' ')
  end
end
