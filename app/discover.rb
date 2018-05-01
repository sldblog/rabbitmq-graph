# frozen_string_literal: true

require 'hutch'
require 'json'
require 'logger'
require 'ruby-progressbar'
require 'uri'

# Using RabbitMQ's HTTP management API, discovers the server's publisher/subscriber topology.
#
# Assumes that:
#  - `consumer_tag`s are set on consumers to the consuming application's name
#  - bound routing keys are in the format of `application_name.entity_name[.action]+`
class Discover
  def initialize(api_url: ENV.fetch('RABBITMQ_API_URI', 'http://guest:guest@localhost:15672/'),
                 api_client: nil,
                 output: $stderr)
    @output_io = output
    Hutch::Logging.logger = Logger.new(output_io)
    configure_hutch_http_api(api_url)
    configure_api_client(api_client)
  end

  def topology
    items = {}

    binding_progress = ProgressBar.create(title: 'Discovering bindings', total: client.bindings.size, output: output_io)
    bindings.each do |binding|
      binding_progress.increment
      queue_name = binding[:queue_name]
      items[queue_name] ||= []
      items[queue_name] << route_from(binding)
    end
    binding_progress.finish

    queue_progress = ProgressBar.create(title: 'Discovering queues', total: client.queues.size, output: output_io)
    bound_queues.each do |queue|
      queue_progress.increment
      bound_consumers(queue).each do |consumer|
        queue_name = consumer[:queue_name]
        items[queue_name] ||= []
        items[queue_name].each { |route| route.merge!(route_to(consumer)) }
      end
    end
    queue_progress.finish

    items.inject([]) do |list, (queue_name, routes)|
      next list unless routes
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

  def bindings
    client.bindings.lazy
          .reject { |binding| binding['destination'] == binding['routing_key'] }
          .reject { |binding| binding['routing_key'].empty? }
          .select { |binding| binding['destination_type'] == 'queue' }
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

  def consumer_to_application_name(tag)
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
    { to_app: consumer_to_application_name(queue[:consumer]) }
  end
end
