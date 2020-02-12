# frozen_string_literal: true

require 'spec_helper'

require 'stringio'
require 'rabbitmq-graph/discover'

RSpec.describe 'integration', integration: true do
  let(:rabbitmq_api_url) { ENV.fetch('RABBITMQ_API_URI') }
  let(:discover) { Discover.new(api_url: rabbitmq_api_url, output: StringIO.new) }

  it 'executes a meaningless test' do
    expect(discover.topology).to be_empty
  end
end
