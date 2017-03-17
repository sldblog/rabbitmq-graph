require 'hutch'
require 'json'
require 'logger'
require 'uri'

class Discover
  APPLICATION_ONLY_LEVEL = 1
  HIGHEST_LEVEL = 2

  def initialize(uri: ENV.fetch('RABBITMQ_URI', 'amqp://guest:guest@127.0.0.1:5672'),
                 api_uri: ENV.fetch('RABBITMQ_API_URI', 'http://127.0.0.1:15672/'),
                 graph_level: ENV.fetch('LEVEL', HIGHEST_LEVEL).to_i,
                 edge_level: ENV.fetch('EDGE_LEVEL', HIGHEST_LEVEL).to_i)
    Hutch::Logging.logger = Logger.new(STDERR)

    Hutch::Config.set(:uri, uri)
    URI(api_uri).tap do |parsed_uri|
      Hutch::Config.set(:mq_api_host, parsed_uri.host)
      Hutch::Config.set(:mq_api_port, parsed_uri.port || (parsed_uri.scheme == 'https' ? 443 : 15672))
      Hutch::Config.set(:mq_api_ssl, parsed_uri.scheme == 'https')
    end

    @graph_level = graph_level
    @edge_level = edge_level
    client
  end

  def client
    return @client if @client
    Hutch.connect
    @client = Hutch.broker.api_client
  end

  def routes
    items = {}
    bindings.each do |binding|
      $stderr.print '.'
      queue_name = binding[:queue_name]
      items[queue_name] ||= []
      items[queue_name] << route_from(binding)
    end

    bound_queues.each do |queue|
      $stderr.print '.'
      queue_name = queue[:queue_name]
      items[queue_name] ||= []
      items[queue_name].each { |route| route.merge!(route_to(queue)) }
    end

    items.inject([]) do |list, pair|
      queue_name, routes = pair
      next unless routes
      list << routes.map do |route|
        route[:queue_name] = queue_name
        route[:to_app] ||= ''
        route[:from_app] ||= ''
        route[:entity] ||= ''
        route[:key] ||= []
        route
      end
    end.flatten
  end

  def to_dot
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

  def bindings
    @bindings ||= client
      .bindings.lazy
      .reject { |binding| binding['destination'] == binding['routing_key'] }
      .reject { |binding| binding['routing_key'].empty? }
      .select { |binding| binding['destination_type'] == 'queue' }
      .map    { |binding| { vhost: binding['vhost'],
                            queue_name: binding['destination'],
                            routing_key: binding['routing_key'] } }
  end

  def bound_queues
    @queues ||= client
      .queues.lazy
      .map      { |queue| JSON.parse client.query_api(path: "/queues/#{URI.escape(queue['vhost'], %r{/})}/#{queue['name']}").body }
      .flat_map { |queue| queue['consumer_details'] }
      .reject(&:empty?)
      .map      { |consumer| { vhost: consumer['queue']['vhost'],
                               queue_name: consumer['queue']['name'],
                               consumer: sanitize_tag(consumer['consumer_tag']) } }
  end

  private

  attr_reader :graph_level, :edge_level

  def sanitize_tag(tag)
    return 'ruby' if tag =~ /^bunny-/ || tag =~ /^hutch-/
    return 'jvm' if tag =~ /^amq\.ctag/
    return tag.split('-')[0..-6].join('-') if tag =~ /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    return tag.split('-')[0..-3].join('-') if tag =~ /[0-9]+-[0-9]+$/
    tag
  end

  def route_from(binding)
    key = binding[:routing_key].split('.')
    { key: key, from_app: key[0], entity: key[1] }
  end

  def route_to(queue)
    { to_app: queue[:consumer] }
  end

  def application_nodes
    applications = routes.map { |route| [route[:from_app], route[:to_app]] }.flatten.sort.uniq
    applications.inject([]) do |list, app|
      label = %Q("#{app}")
      label += ' [fillcolor=red]' if app.empty?
      list << label
    end
  end

  def entity_nodes
    return [] unless graph_level > APPLICATION_ONLY_LEVEL
    entities = routes.map { |route| route[:entity] }.sort.uniq
    entities.inject([]) do |list, entity|
      list << %Q("#{entity}")
    end
  end

  def message_edges
    routes.inject([]) do |list, route|
      qualifier = route[:key][edge_level..-1]&.join('.').to_s

      edge_options = []
      edge_options << %Q(label="#{qualifier}")
      edge_options << %Q(color="red") if route[:to_app].to_s.empty?

      list << %Q(#{route_to_path(route)} [#{edge_options.join(' ')}])
    end.uniq
  end

  def route_to_path(route)
    [].tap { |path|
      path << route[:from_app]
      path << route[:entity] if graph_level > APPLICATION_ONLY_LEVEL
      path << route[:to_app]
    }.map { |text| %("#{text}") }.join('->')
  end
end
