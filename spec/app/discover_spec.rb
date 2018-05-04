# frozen_string_literal: true

require 'spec_helper'
require 'app/discover'

RSpec.describe Discover do
  describe '#new' do
    let(:api_client) { double(:api_client) }

    it 'configures hutch based on HTTPS URL' do
      described_class.new(api_url: 'https://hostgiven/', api_client: api_client)
      expect(Hutch::Config[:mq_api_host]).to eq('hostgiven')
      expect(Hutch::Config[:mq_api_port]).to eq(443)
      expect(Hutch::Config[:mq_api_ssl]).to eq(true)
    end

    it 'configures hutch based on HTTP URL' do
      described_class.new(api_url: 'http://hostgiven/', api_client: api_client)
      expect(Hutch::Config[:mq_api_host]).to eq('hostgiven')
      expect(Hutch::Config[:mq_api_port]).to eq(80)
      expect(Hutch::Config[:mq_api_ssl]).to eq(false)
    end

    it 'configures hutch based on URL with username, password and port' do
      described_class.new(api_url: 'http://usergiven:passwordgiven@hostgiven:12345/', api_client: api_client)
      expect(Hutch::Config[:mq_api_host]).to eq('hostgiven')
      expect(Hutch::Config[:mq_username]).to eq('usergiven')
      expect(Hutch::Config[:mq_password]).to eq('passwordgiven')
      expect(Hutch::Config[:mq_api_port]).to eq(12_345)
    end
  end

  describe '#topology' do
    let(:fake_output) { StringIO.new }
    let(:api_client) { double(:api_client, bindings: bindings, queues: queues) }
    let(:bindings) { [] }
    let(:queues) { [] }

    def register_queue_details_call(api_client, path, consumer_details)
      body = { 'consumer_details' => consumer_details }
      response = double(:response, body: body.to_json)
      allow(api_client).to receive(:query_api).with(path: path).and_return(response)
    end

    let(:setup_transaction_queue) do
      queues << { 'name' => 'transaction_queue', 'vhost' => '/' }
      register_queue_details_call(
        api_client,
        '/queues/%2F/transaction_queue',
        [
          { 'consumer_tag' => 'payments-1', 'queue' => { 'vhost' => '/', 'name' => 'transaction_queue' } },
          { 'consumer_tag' => 'payments-2', 'queue' => { 'vhost' => '/', 'name' => 'transaction_queue' } }
        ]
      )
    end

    let(:setup_empty_transaction_queue) do
      queues << { 'name' => 'transaction_queue', 'vhost' => '/' }
      register_queue_details_call(api_client, '/queues/%2F/transaction_queue', [])
    end

    subject(:topology) { described_class.new(api_client: api_client, output: fake_output).topology }

    it 'reports all consumer tags for each routing key in each queue' do
      bindings << { 'source' => 'standard', 'destination' => 'transaction_queue',
                    'routing_key' => 'ledger.payment.made', 'destination_type' => 'queue' }
      setup_transaction_queue

      expect(topology).to contain_exactly(
        Route.new(queue_name: 'transaction_queue', routing_key: 'ledger.payment.made', consumer_tag: 'payments-1'),
        Route.new(queue_name: 'transaction_queue', routing_key: 'ledger.payment.made', consumer_tag: 'payments-2')
      )
    end

    it 'reports queues without consumers as empty consumer tags for each routing key in each queue' do
      bindings << { 'source' => 'standard', 'destination' => 'transaction_queue',
                    'routing_key' => 'ledger.payment.made', 'destination_type' => 'queue' }
      setup_empty_transaction_queue

      expect(topology).to contain_exactly(
        Route.new(queue_name: 'transaction_queue', routing_key: 'ledger.payment.made', consumer_tag: nil)
      )
    end

    it 'reports queues without routing key bindings as empty routing keys for each queue and consumer tag' do
      setup_transaction_queue

      expect(topology).to contain_exactly(
        Route.new(queue_name: 'transaction_queue', routing_key: '', consumer_tag: 'payments-1'),
        Route.new(queue_name: 'transaction_queue', routing_key: '', consumer_tag: 'payments-2')
      )
    end

    it 'skips bindings that do not have a source' do
      bindings << { 'source' => '', 'destination' => 'nosource', 'routing_key' => 'nosource',
                    'destination_type' => 'queue' }
      setup_transaction_queue

      expect(topology.map(&:to_h)).not_to include(hash_including(routing_key: 'nosource'))
    end

    it 'skips bindings that do not have routing keys defined' do
      bindings << { 'source' => 'standard', 'destination' => 'unreachable_queue', 'routing_key' => '',
                    'destination_type' => 'queue' }
      setup_transaction_queue

      expect(topology.map(&:to_h)).not_to include(hash_including(queue_name: 'unreachable_queue'))
    end

    it 'skips bindings that do not bind to queues' do
      bindings << { 'source' => 'standard', 'destination' => '???', 'routing_key' => 'unknown_routing',
                    'destination_type' => 'unknown' }
      setup_transaction_queue

      expect(topology.map(&:to_h)).not_to include(hash_including(routing_key: 'unknown_routing'))
    end
  end
end
