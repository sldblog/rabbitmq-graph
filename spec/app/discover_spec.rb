# frozen_string_literal: true

require 'spec_helper'
require 'app/discover'

RSpec.describe Discover do
  let(:api_client) { double(:api_client) }

  describe '#new' do
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
end
