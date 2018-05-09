# frozen_string_literal: true

require 'spec_helper'
require 'rabbitmq-graph/route'

RSpec.describe Route do
  it 'extracts the source application, entity and actions from the given routing key' do
    route = Route.new(queue_name: 'test', routing_key: 'source.entity.action1.action2')
    expect(route.source_app).to eq('source')
    expect(route.entity).to eq('entity')
    expect(route.actions).to eq(%w[action1 action2])
  end

  it 'marks a route with a defined routing key as a route with a source' do
    route = Route.new(queue_name: 'test', routing_key: 'something_defined')
    expect(route.missing_source?).to eq(false)
  end

  it 'marks a route with a defined consumer tag as a route with a target' do
    route = Route.new(queue_name: 'test', consumer_tag: 'something_defined')
    expect(route.missing_target?).to eq(false)
  end

  it 'marks a route without a routing key as a route missing a source' do
    route = Route.new(queue_name: 'test', routing_key: nil, consumer_tag: 'something_defined')
    expect(route.missing_source?).to eq(true)
    expect(route.source_app).to eq('no-routing-key-binding')
  end

  it 'marks a route without a consumer tag as a route without a target' do
    route = Route.new(queue_name: 'test', routing_key: 'something_defined', consumer_tag: nil)
    expect(route.missing_target?).to eq(true)
    expect(route.target_app).to eq('no-consumers')
  end

  it 'marks a route with a "bunny" consumer tag prefix as a route with a default consumer tag' do
    route = Route.new(queue_name: 'test', consumer_tag: 'bunny-123-123')
    expect(route.default_consumer_tag?).to eq(true)
    expect(route.target_app).to eq('default-consumer-tag')
  end

  it 'marks a route with a "hutch" consumer tag prefix as a route with a default consumer tag' do
    route = Route.new(queue_name: 'test', consumer_tag: 'hutch-123-123')
    expect(route.default_consumer_tag?).to eq(true)
    expect(route.target_app).to eq('default-consumer-tag')
  end

  it 'marks a route with an "amq.ctag" consumer tag prefix as a route with a default consumer tag' do
    route = Route.new(queue_name: 'test', consumer_tag: 'amq.ctag-123-123')
    expect(route.default_consumer_tag?).to eq(true)
    expect(route.target_app).to eq('default-consumer-tag')
  end

  it 'marks a route with other consumer tags as a route with a custom consumer tag' do
    route = Route.new(queue_name: 'test', consumer_tag: 'custom-e8e8cf42-7af5-4d27-9891-ef7ac238a9bd')
    expect(route.default_consumer_tag?).to eq(false)
  end

  it 'extracts a custom consumer tag prefix before a UUID as the "target" application name' do
    route = Route.new(queue_name: 'test', consumer_tag: 'custom-dashes-e8e8cf42-7af5-4d27-9891-ef7ac238a9bd')
    expect(route.target_app).to eq('custom-dashes')
  end

  it 'extracts a custom consumer tag prefix before two number groups as the "target" application name' do
    route = Route.new(queue_name: 'test', consumer_tag: 'custom-dashes/1-1234-623672')
    expect(route.target_app).to eq('custom-dashes/1')

    route = Route.new(queue_name: 'test', consumer_tag: 'custom-dashes/2-9-2')
    expect(route.target_app).to eq('custom-dashes/2')

    route = Route.new(queue_name: 'test', consumer_tag: 'custom-dashes/3-917265125619-223')
    expect(route.target_app).to eq('custom-dashes/3')
  end
end
