# frozen_string_literal: true

require 'spec_helper'
require 'app/dot_format'
require 'app/route'

RSpec.describe DotFormat do
  describe '#present' do
    let(:show_entities) { true }
    let(:label_detail) { %i[actions] }

    let(:topology) do
      [route(source_app: 'from', target_app: 'to', entity: 'thing', actions: %w[happened]),
       route(source_app: 'from', target_app: 'another', entity: 'clowns', actions: %w[coming fast])]
    end

    subject(:present) do
      described_class.new(topology: topology, show_entities: show_entities, label_detail: label_detail).present
    end
    let(:application_subgraph) { present.match(/subgraph Apps {(.*?)}/m)[1] }
    let(:entity_subgraph) { present.match(/subgraph Entities {(.*?)}/m)[1] }

    it 'shows all application nodes in a subgraph' do
      expect(application_subgraph).to include(%("from" []\n))
      expect(application_subgraph).to include(%("to" []\n))
      expect(application_subgraph).to include(%("another" []\n))
    end

    describe 'entity nodes with entities shown' do
      let(:show_entities) { true }

      it 'shows all entity nodes in a subgraph' do
        expect(entity_subgraph).to include(%("thing"\n))
        expect(entity_subgraph).to include(%("clowns"\n))
      end
    end

    describe 'entity nodes with entities hidden' do
      let(:show_entities) { false }

      it 'does not show entity nodes' do
        expect(present).not_to include('subgraph Entities')
      end
    end

    describe 'application relationships with entities shown' do
      let(:show_entities) { true }

      it 'shows publisher->entity->consumer relationship between applications' do
        expect(present).to include(%("from"->"thing"->"to"))
        expect(present).to include(%("from"->"clowns"->"another"))
      end
    end

    describe 'application relationships with entities hidden' do
      let(:show_entities) { false }

      it 'shows publisher->consumer relationship between applications' do
        expect(present).to include(%("from"->"to"))
        expect(present).to include(%("from"->"another"))
      end
    end

    describe 'edge labels for empty label detail setting' do
      let(:label_detail) { [] }

      it 'shows empty labels' do
        expect(present).to include(%(->"to" [label=""]\n))
        expect(present).to include(%(->"another" [label=""]\n))
      end
    end

    describe 'edge labels for "entity" label detail setting' do
      let(:label_detail) { %i[entity] }

      it 'shows the entity as label' do
        expect(present).to include(%(->"to" [label="thing"]\n))
        expect(present).to include(%(->"another" [label="clowns"]\n))
      end
    end

    describe 'edge labels for "actions" label detail setting' do
      let(:label_detail) { %i[actions] }

      it 'shows the actions as label' do
        expect(present).to include(%(->"to" [label="happened"]\n))
        expect(present).to include(%(->"another" [label="coming.fast"]\n))
      end
    end

    describe 'edge labels for "entity.actions" label detail setting' do
      let(:label_detail) { %i[entity actions] }

      it 'shows the concatenated entity and actions as label' do
        label_detail.replace(%i[entity actions])
        expect(present).to include(%(->"to" [label="thing.happened"]\n))
        expect(present).to include(%(->"another" [label="clowns.coming.fast"]\n))
      end
    end

    describe 'when a consumer has a default name' do
      let(:topology) do
        [route(source_app: 'demo', target_app: 'default', entity: 'entity', actions: %w[action],
               default_consumer_tag?: true)]
      end

      it 'shows the default application node with orange colour' do
        expect(application_subgraph).to include(%("default" [fillcolor="orange"]\n))
      end

      it 'shows regular edges' do
        expect(present).to include(%("demo"->"entity"->"default" [label="action"]\n))
      end
    end

    describe 'when a queue with a routing key has no consumer applications' do
      let(:topology) do
        [route(source_app: 'connected_part', target_app: 'none', entity: 'entity', actions: %w[action],
               missing_target?: true)]
      end

      it 'shows the disconnected node with red colour' do
        expect(application_subgraph).to include(%("none" [fillcolor="red"]\n))
      end

      it 'shows edges without consumers with red colour' do
        expect(present).to include(%("connected_part"->"entity"->"none" [label="action" color="red"]\n))
      end
    end

    describe 'when a queue has no routing keys bound' do
      let(:topology) do
        [route(source_app: 'none', target_app: 'connected_part', entity: '', actions: [],
               missing_source?: true)]
      end

      it 'shows the missing application node with red colour' do
        expect(application_subgraph).to include(%("none" [fillcolor="red"]\n))
      end

      it 'shows edges without consumers with red colour' do
        expect(present).to include(%("none"->""->"connected_part" [label="" color="red"]\n))
      end
    end
  end
end
