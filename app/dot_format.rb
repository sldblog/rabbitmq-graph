# frozen_string_literal: true

require 'app/discover'

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
    applications = topology.map { |route| [route[:from_app], route[:to_app]] }.flatten.sort.uniq
    applications.map do |app|
      properties = []
      properties << 'fillcolor="red"' if app_missing?(app)
      properties << 'fillcolor="orange"' if default_tag?(app)
      %("#{app}" [#{properties.join(' ')}])
    end
  end

  def entity_nodes
    entities = topology.map { |route| route[:entity] }.sort.uniq
    entities.map { |entity| %("#{entity}") }
  end

  def message_edges
    topology.map { |route| %(#{route_path(route)} [#{route_properties(route)}]) }.uniq
  end

  def route_path(route)
    path = []
    path << route[:from_app]
    path << route[:entity] if show_entities
    path << route[:to_app]
    path.map { |text| %("#{text}") }.join('->')
  end

  def route_properties(route)
    label = label_detail.map { |detail| route[detail] }.join('.').to_s
    properties = []
    properties << %(label="#{label}")
    properties << %(color="red") if app_missing?(route[:to_app]) || app_missing?(route[:from_app])
    properties.join(' ')
  end

  def app_missing?(app)
    [Discover::MISSING_CONSUMER_TAG, Discover::MISSING_BINDING_TAG].include? app.to_s
  end

  def default_tag?(app)
    app.to_s == Discover::DEFAULT_CONSUMER_TAG
  end
end
