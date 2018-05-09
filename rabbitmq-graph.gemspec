# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'rabbitmq-graph'
  s.version     = '0.1.1'
  s.summary     = 'Discover RabbitMQ topology'
  s.description = 'Map out RabbitMQ topology with the use of routing key conventions and consumer tags.'
  s.authors     = ['David Lantos']
  s.email       = 'david.lantos+rabbitmq-graph@gmail.com'
  s.bindir      = 'bin'
  s.executables = ['rabbitmq-graph']
  s.files       = `git ls-files lib bin *.gemspec *.md`.split
  s.homepage    = 'https://github.com/sldblog/rabbitmq-graph'
  s.metadata    = { 'source_code_uri' => 'https://github.com/sldblog/rabbitmq-graph' }

  s.add_runtime_dependency 'hutch', '~> 0.24'
  s.add_runtime_dependency 'ruby-progressbar', '~> 1.9'
end
