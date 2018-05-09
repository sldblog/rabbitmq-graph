# frozen_string_literal: true

require 'spec_helper'
require 'app/markdown_table_format'
require 'app/route'

RSpec.describe MarkdownTableFormat do
  let(:topology) { [] }
  subject(:present) { described_class.new(topology: topology).present }

  it 'shows routes without consumers as a separate section' do
    topology << route(queue_name: 'no_consumer_queue', source_app: 'connected_part', target_app: 'none',
                      entity: 'entity', actions: %w[action], missing_target?: true)

    expect(present).to include(
      <<~TABLE.strip
        # Routes without consumers

        | Publisher application | Consumer application | Entity | Actions | Queue |
        | --- | --- | --- | --- | --- |
        | connected_part | none | entity | action | no_consumer_queue |
      TABLE
    )
  end

  it 'shows routes without bindings as a separate section' do
    topology << route(queue_name: 'no_binding_queue', source_app: 'none', target_app: 'connected_part',
                      missing_source?: true)

    expect(present).to include(
      <<~TABLE.strip
        # Routes without publisher bindings

        | Publisher application | Consumer application | Entity | Actions | Queue |
        | --- | --- | --- | --- | --- |
        | none | connected_part |  |  | no_binding_queue |
      TABLE
    )
  end

  it 'shows routes with default consumer tags as a separate section' do
    topology << route(queue_name: 'default_tag_queue', source_app: 'connected_part', target_app: 'unknown',
                      entity: 'entity', actions: %w[action], default_consumer_tag?: true)

    expect(present).to include(
      <<~TABLE.strip
        # Routes with default consumer names

        | Publisher application | Consumer application | Entity | Actions | Queue |
        | --- | --- | --- | --- | --- |
        | connected_part | unknown | entity | action | default_tag_queue |
      TABLE
    )
  end

  it 'shows connected routes as a separate section' do
    topology << route(queue_name: 'q1', source_app: 'from', target_app: 'to', entity: 'entity', actions: %w[action])
    topology << route(queue_name: 'q2', source_app: 'from', target_app: 'to', entity: 'fire', actions: %w[get out])

    expect(present).to include(
      <<~TABLE.strip
        # Named, connected routes

        | Publisher application | Consumer application | Entity | Actions | Queue |
        | --- | --- | --- | --- | --- |
        | from | to | entity | action | q1 |
        | from | to | fire | get.out | q2 |
      TABLE
    )
  end
end
