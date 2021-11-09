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

  it 'maps the claim service route in dot (graphviz) format' do
    dot_command = "bundle exec bin/rabbitmq-graph --format=DotFormat --url=#{rabbitmq_api_url}"
    expect { system(dot_command) }.to(
      output(/"claim_service_v2"->"claim"->"integration_test" \[label="submitted"\]/).to_stdout_from_any_process
    )
  end

  it 'successfully writes and reads a topology file' do
    save_command = "bundle exec bin/rabbitmq-graph --save-topology=topology_cache --url=#{rabbitmq_api_url}"
    system(save_command)

    read_command = 'bundle exec bin/rabbitmq-graph --read-topology=topology_cache --format=DotFormat ' \
                   "--url=#{rabbitmq_api_url}"
    expect { system(read_command) }.to(
      output(/"claim_service_v2"->"claim"->"integration_test" \[label="submitted"\]/).to_stdout_from_any_process
    )
  end

  it 'maps the claim service route in markdown table format' do
    markdown_command = "bundle exec bin/rabbitmq-graph --format=MarkdownTableFormat --url=#{rabbitmq_api_url}"
    expect { system(markdown_command) }.to(
      output(/| claim_service_v2 | integration_test | claim | submitted | new_claims |/).to_stdout_from_any_process
    )
  end
end
