# frozen_string_literal: true

require 'hutch'
require 'json'
require 'logger'
require 'ruby-progressbar'
require 'uri'
require 'rabbitmq-graph/route'

# Using RabbitMQ's HTTP management API, discovers the server's publisher/subscriber topology.
#
# Assumes that:
#  - `consumer_tag`s are set on consumers to the consuming application's name
#  - bound routing keys are in the format of `application_name.entity_name[.action]+`
class Discover
  def initialize(api_url: ENV.fetch('RABBITMQ_API_URI', 'http://guest:guest@localhost:15672/'),
                 api_client: nil, output: $stderr)
    @output_io = output
    Hutch::Logging.logger = Logger.new(output_io)
    configure_hutch_http_api(api_url)
    configure_api_client(api_client)
  end

  def topology
    all_publishers = discover_routing_keys
    all_consumers = discover_queues_and_consumers
    queue_names = all_publishers.keys | all_consumers.keys

    queue_names.inject([]) do |result, queue_name|
      publishers = all_publishers[queue_name] || []
      publishers << {} if publishers.empty?
      consumers = all_consumers[queue_name] || []
      consumers << {} if consumers.empty?

      routes = publishers
               .flat_map { |route| consumers.map { |consumer| route.merge(consumer) } }
               .map { |route| route.delete_if { |_key, value| value.nil? } }
               .map { |route| Route.new(queue_name: queue_name, **route) }
               .uniq
      result.concat(routes)
    end
  end

  private

  attr_reader :client, :output_io

  def configure_hutch_http_api(api_url)
    parsed_uri = URI(api_url)
    Hutch::Config.set(:mq_api_host, parsed_uri.host)
    Hutch::Config.set(:mq_username, parsed_uri.user || 'guest')
    Hutch::Config.set(:mq_password, parsed_uri.password || 'guest')
    Hutch::Config.set(:mq_api_port, parsed_uri.port)
    Hutch::Config.set(:mq_api_ssl, parsed_uri.scheme == 'https')
  end

  def configure_api_client(api_client)
    return @client = api_client if api_client

    broker = Hutch::Broker.new
    broker.set_up_api_connection
    @client = broker.api_client
  end

  def discover_routing_keys
    items = {}
    ProgressBar.create(title: 'Discovering bindings', total: client.bindings.size, output: output_io).tap do |progress|
      bindings.each do |mq_binding|
        queue_name = mq_binding[:queue_name]
        items[queue_name] ||= []
        items[queue_name] << { routing_key: mq_binding[:routing_key] }
        progress.increment
      end
      progress.finish
    end
    items
  end

  def discover_queues_and_consumers
    items = {}
    ProgressBar.create(title: 'Discovering queues', total: client.queues.size, output: output_io).tap do |progress|
      bound_queues.each do |queue|
        bound_consumers(queue).each do |consumer|
          queue_name = consumer[:queue_name]
          items[queue_name] ||= []
          items[queue_name] << { consumer_tag: consumer[:consumer] }
        end
        progress.increment
      end
      progress.finish
    end
    items
  end

  def bindings
    client.bindings.lazy
          .select { |binding| binding['destination_type'] == 'queue' }
          .reject { |binding| binding['routing_key'].empty? }
          .reject { |binding| binding['source'].empty? }
          .map    { |binding_data| extract_binding_data(binding_data) }
  end

  def bound_queues
    client.queues.lazy
          .map { |queue| fetch_queue_data(queue['vhost'], queue['name']) }
          .map { |queue| queue['consumer_details'] }
  end

  def bound_consumers(queue_data)
    queue_data
      .flatten
      .reject(&:empty?)
      .map { |consumer_data| extract_consumer_data(consumer_data) }
  end

  def extract_binding_data(binding_data)
    {
      vhost: binding_data['vhost'],
      queue_name: binding_data['destination'],
      routing_key: binding_data['routing_key']
    }
  end

  def extract_consumer_data(consumer_data)
    {
      vhost: consumer_data['queue']['vhost'],
      queue_name: consumer_data['queue']['name'],
      consumer: consumer_data['consumer_tag']
    }
  end

  def fetch_queue_data(vhost, name)
    escaped_vhost_path = URI.encode_www_form_component(vhost)
    JSON.parse(client.query_api(path: "/queues/#{escaped_vhost_path}/#{name}").body)
  end
end
