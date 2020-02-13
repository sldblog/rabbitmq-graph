# frozen_string_literal: true

require 'hutch'

Hutch::Config.set(:consumer_tag_prefix, 'integration_test')

class IntegrationConsumer
  include Hutch::Consumer

  consume 'claim_service_v2.claim.submitted'
  queue_name 'new_claims'

  def process(_message)
    nil
  end
end
