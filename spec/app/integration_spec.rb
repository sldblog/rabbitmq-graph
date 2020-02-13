# frozen_string_literal: true

require 'spec_helper'

require 'rest-client'
require 'stringio'
require 'uri'
require 'rabbitmq-graph/discover'

RSpec.describe 'integration', integration: true do
  def rabbitmq_api_url
    ENV.fetch('RABBITMQ_API_URI')
  end

  def rabbitmq_url
    ENV.fetch('RABBITMQ_URI')
  end

  def read_consumers
    result = RestClient.get("#{rabbitmq_api_url}/api/consumers/%2f")
    JSON.parse(result.body)
  end

  def wait_for_consumer_to_be_ready
    Timeout.timeout(10) do
      sleep 0.3 until read_consumers.any?
    end
  end

  before :all do
    hutch_env = { 'HUTCH_URI' => rabbitmq_url, 'HUTCH_MQ_API_HOST' => URI.parse(rabbitmq_api_url).hostname }
    @pid = Process.spawn(hutch_env, 'bundle exec hutch --require spec/support/integration_consumer.rb')
    wait_for_consumer_to_be_ready
  end

  after :all do
    Process.kill('TERM', @pid)
    Process.wait(@pid)
  end

  let(:discover) { Discover.new(api_url: rabbitmq_api_url, output: StringIO.new) }

  it 'maps the claim service route' do
    route = discover.topology.first
    expect(route.source_app).to eq('claim_service_v2')
    expect(route.entity).to eq('claim')
    expect(route.actions).to include('submitted')
    expect(route.target_app).to eq('integration_test')
  end
end
