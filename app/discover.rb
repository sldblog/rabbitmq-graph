require 'hutch'
require 'uri'
require 'json'

class Discover
  def initialize(rabbitmq_uri: ENV.fetch('RABBITMQ_URI', 'amqp://guest:guest@127.0.0.1:5672'),
                 rabbitmq_api_uri: ENV.fetch('RABBITMQ_API_URI', 'http://127.0.0.1:15672/'))
    Hutch::Config.set(:uri, rabbitmq_uri)
    URI(rabbitmq_api_uri).tap do |uri|
      Hutch::Config.set(:mq_api_host, uri.host)
      Hutch::Config.set(:mq_api_port, uri.port || (uri.scheme == 'https' ? 443 : 15672))
      Hutch::Config.set(:mq_api_ssl, uri.scheme == 'https')
    end
  end

  def client
    Hutch.connect
    Hutch.broker.api_client
  end

  def graph
    {}.tap do |routes|
      bound_queues.each do |queue|
        routes[queue[:queue]] = route_to(queue)
      end

      bindings.each do |binding|
        queue = routes[binding[:queue]]
        next unless queue
        queue[:routes] ||= []
        queue[:routes] << route_from(binding)
      end
    end
  end

  def bindings
    @bindings ||= client
      .bindings.lazy
      .reject { |binding| binding['destination'] == binding['routing_key'] }
      .reject { |binding| binding['routing_key'].empty? }
      .select { |binding| binding['destination_type'] == 'queue' }
      .map    { |binding| { vhost: binding['vhost'], queue: binding['destination'], routing_key: binding['routing_key'] } }
  end

  def bound_queues
    @queues ||= client
      .queues.lazy
      .map      { |queue| JSON.parse client.query_api(path: "/queues/#{queue['vhost']}/#{queue['name']}").body }
      .flat_map { |queue| queue['consumer_details'] }
      .reject(&:empty?)
      .map      { |consumer| { vhost: consumer['queue']['vhost'],
                               queue: consumer['queue']['name'],
                               consumer: sanitize_tag(consumer['consumer_tag']) } }
  end

  private

  def sanitize_tag(tag)
    return 'ruby' if tag =~ /^bunny-/ || tag =~ /^hutch-/
    return 'jvm' if tag =~ /^amq\.ctag/
    return tag.split('-')[0..-6].join('-') if tag =~ /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    return tag.split('-')[0..-3].join('-') if tag =~ /[0-9]+-[0-9]+$/
    tag
  end

  def route_from(binding)
    { key: binding[:routing_key],
      entity: binding[:routing_key].split('.')[1],
      from_app: binding[:routing_key].split('.')[0] }
  end

  def route_to(queue)
    { to_app: queue[:consumer] }
  end
end
