# frozen_string_literal: true

require 'bundler/setup'
$LOAD_PATH.unshift(Bundler.root) unless $LOAD_PATH.include?(Bundler.root)

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
end

require 'support/route_helper'
RSpec.configure do |c|
  c.include RouteHelper
end
