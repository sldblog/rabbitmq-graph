# frozen_string_literal: true

require 'hutch'
require 'json'
require 'logger'
require 'uri'

class Discover
  def initialize(uri: ENV.fetch('RABBITMQ_URI', 'amqp://guest:guest@127.0.0.1:5672'),
                 api_uri: ENV.fetch('RABBITMQ_API_URI', 'http://127.0.0.1:15672/'),
                 api_client: nil)
    Hutch::Logging.logger = Logger.new(STDERR)

    Hutch::Config.set(:uri, uri)
    URI(api_uri).tap do |parsed_uri|
      Hutch::Config.set(:mq_api_host, parsed_uri.host)
      Hutch::Config.set(:mq_api_port, parsed_uri.port || (parsed_uri.scheme == 'https' ? 443 : 15_672))
      Hutch::Config.set(:mq_api_ssl, parsed_uri.scheme == 'https')
    end

    @client = api_client
    unless client
      Hutch.connect
      @client = Hutch.broker.api_client
    end
  end

  def topology
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

  attr_reader :client

  def bindings
    @bindings ||= client
                  .bindings.lazy
                  .reject { |binding| binding['destination'] == binding['routing_key'] }
                  .reject { |binding| binding['routing_key'].empty? }
                  .select { |binding| binding['destination_type'] == 'queue' }
                  .map    { |binding_data| extract_binding_data(binding_data) }
  end

  def bound_queues
    @bound_queues ||= client
                      .queues.lazy
                      .map      { |queue| queue_data(queue['vhost'], queue['name']) }
                      .flat_map { |queue| queue['consumer_details'] }
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

  def queue_data(vhost, name)
    escaped_vhost_path = URI.escape(vhost, %r{/})
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
