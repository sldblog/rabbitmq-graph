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
    apps = <<-APPS
      subgraph Apps {
        node [shape=hexagon fillcolor=yellow style=filled]
        #{application_nodes.join("\n")}
      }
    APPS

    entities = <<-ENTITIES
      subgraph Entities {
        node [shape=box fillcolor=turquoise style=filled]
        #{entity_nodes.join("\n")}
      }
    ENTITIES

    <<-GRAPH
    digraph G {
      #{apps}
      #{entities}
      #{message_edges.join("\n")}
    }
    GRAPH
  end

  private

  attr_reader :topology, :graph_level, :edge_level

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
    entities.inject([]) do |list, entity|
      list << %("#{entity}")
    end
  end

  def message_edges
    topology.inject([]) do |list, route|
      qualifier = route[:key][edge_level..-1]&.join('.').to_s

      edge_options = []
      edge_options << %(label="#{qualifier}")
      edge_options << %(color="red") if route[:to_app].to_s.empty?

      list << %(#{route_to_path(route)} [#{edge_options.join(' ')}])
    end.uniq
  end

  def route_to_path(route)
    path = []
    path << route[:from_app]
    path << route[:entity] if graph_level > APPLICATION_ONLY_LEVEL
    path << route[:to_app]
    path.map { |text| %("#{text}") }.join('->')
  end
end
