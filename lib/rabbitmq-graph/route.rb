# frozen_string_literal: true

# Extracts publisher/consumer application names and routing key fragments from routing data
class Route
  DEFAULT_CONSUMER_TAG = 'default-consumer-tag'
  MISSING_SOURCE_LABEL = 'no-routing-key-binding'
  MISSING_TARGET_LABEL = 'no-consumers'

  def initialize(queue_name:, routing_key: nil, consumer_tag: nil)
    @queue_name = queue_name
    @routing_fragments = routing_key.to_s.split('.')
    @consumer_tag = consumer_tag

    @source_app = routing_fragments[0] || MISSING_SOURCE_LABEL
    @entity = routing_fragments[1] || ''
    @actions = routing_fragments[2..-1] || []
    @target_app = consumer_tag_to_application_name(consumer_tag) || MISSING_TARGET_LABEL
  end

  attr_reader :source_app, :target_app, :entity, :actions, :queue_name

  def missing_source?
    source_app == MISSING_SOURCE_LABEL
  end

  def missing_target?
    target_app == MISSING_TARGET_LABEL
  end

  def default_consumer_tag?
    target_app == DEFAULT_CONSUMER_TAG
  end

  def to_h
    { queue_name: queue_name, routing_key: routing_fragments.join('.'), consumer_tag: consumer_tag }
  end

  def ==(other)
    eql?(other)
  end

  def eql?(other)
    [queue_name, routing_fragments, consumer_tag] == [other.queue_name, other.routing_fragments, other.consumer_tag]
  end

  protected

  attr_reader :routing_fragments, :consumer_tag

  private

  def consumer_tag_to_application_name(tag)
    return DEFAULT_CONSUMER_TAG if tag =~ /^bunny-/ || tag =~ /^hutch-/ || tag =~ /^amq\.ctag/
    return tag.split('-')[0..-6].join('-') if tag =~ /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    return tag.split('-')[0..-3].join('-') if tag =~ /[0-9]+-[0-9]+$/

    tag
  end
end
