# frozen_string_literal: true

require 'rabbitmq-graph/route'

module RouteHelper
  def route(data)
    defaults = {
      missing_source?: false,
      missing_target?: false,
      default_consumer_tag?: false,
      entity: '',
      actions: [],
      source_app: nil,
      target_app: nil
    }
    instance_double(Route, defaults.merge(data))
  end
end
