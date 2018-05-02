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
          { 'consumer_tag' => 'payments-6f6924a1-9cbb-4add-b62c-441e36a9ff30',
            'queue' => { 'vhost' => '/', 'name' => 'transaction_queue' } },
          { 'consumer_tag' => 'payments-6701018f-12c8-445a-a8a5-5e80704d9b49',
            'queue' => { 'vhost' => '/', 'name' => 'transaction_queue' } }
        ]
      )
    end

    let(:setup_empty_transaction_queue) do
      queues << { 'name' => 'transaction_queue', 'vhost' => '/' }
      register_queue_details_call(api_client, '/queues/%2F/transaction_queue', [])
    end

    subject(:topology) { described_class.new(api_client: api_client, output: fake_output).topology }

    it 'connects publisher applications to consumer applications via routing keys and consumer tags' do
      bindings << { 'destination' => 'transaction_queue', 'routing_key' => 'ledger.payment.made',
                    'destination_type' => 'queue' }
      setup_transaction_queue

      expect(topology).to contain_exactly(
        from_app: 'ledger',
        to_app: 'payments',
        entity: 'payment',
        actions: %w[made],
        queue_name: 'transaction_queue'
      )
    end

    it 'reports routing keys without any consumers as having no consumer applications' do
      bindings << { 'destination' => 'transaction_queue', 'routing_key' => 'ledger.payment.made',
                    'destination_type' => 'queue' }
      setup_empty_transaction_queue

      expect(topology).to contain_exactly(
        from_app: 'ledger',
        to_app: '',
        entity: 'payment',
        actions: %w[made],
        queue_name: 'transaction_queue'
      )
    end

    it 'reports queues without routing keys as having no publisher applications' do
      setup_transaction_queue

      expect(topology).to contain_exactly(
        from_app: '',
        to_app: 'payments',
        entity: '',
        actions: [],
        queue_name: 'transaction_queue'
      )
    end

    it 'skips bindings that are circular' do
      bindings << { 'destination' => 'same', 'routing_key' => 'same', 'destination_type' => 'queue' }
      setup_transaction_queue

      expect(topology).not_to include(hash_including(from_app: 'same'))
    end

    it 'skips bindings that do not have routing keys defined' do
      bindings << { 'destination' => 'unreachable_queue', 'routing_key' => '', 'destination_type' => 'queue' }
      setup_transaction_queue

      expect(topology).not_to include(hash_including(queue_name: 'unreachable_queue'))
    end

    it 'skips bindings that do not bind to queues' do
      bindings << { 'destination' => '???', 'routing_key' => 'unknown_routing', 'destination_type' => 'unknown' }
      setup_transaction_queue

      expect(topology).not_to include(hash_including(from_app: 'unknown_routing'))
    end
  end
end
