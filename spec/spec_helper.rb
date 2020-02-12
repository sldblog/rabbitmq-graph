# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
end

require 'rabbitmq-graph'
require 'support/route_helper'
RSpec.configure do |c|
  c.include RouteHelper
  c.filter_run_excluding integration: true
end
