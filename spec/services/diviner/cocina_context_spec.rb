# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/diviner/cocina_context'

RSpec.describe Diviner::CocinaContext do
  let(:relation) { instance_double('Relation') }

  before do
    stub_const('CocinaSchemaDocument', class_double(CocinaSchemaDocument))
    allow(CocinaSchemaDocument).to receive(:limit).with(200).and_return(relation)
  end

  it 'returns a fallback when no local docs are loaded' do
    allow(relation).to receive(:to_a).and_return([])

    expect(described_class.for_request('title reports')).to eq('(no local cocina schema docs loaded; run rake cocina:ingest_models)')
  end

  it 'ranks matching documents ahead of non-matching documents' do
    title_doc = instance_double(CocinaSchemaDocument, path: 'title.json', content: 'Title title value')
    subject_doc = instance_double(CocinaSchemaDocument, path: 'subject.json', content: 'Subject content only')
    allow(relation).to receive(:to_a).and_return([subject_doc, title_doc])

    result = described_class.for_request('title report')

    expect(result).to start_with("FILE: title.json\nTitle title value")
    expect(result).not_to include('subject.json')
  end

  it 'falls back to the first docs when no tokens match' do
    first_doc = instance_double(CocinaSchemaDocument, path: 'first.json', content: 'Alpha')
    second_doc = instance_double(CocinaSchemaDocument, path: 'second.json', content: 'Beta')
    allow(relation).to receive(:to_a).and_return([first_doc, second_doc])

    result = described_class.for_request('zzz unmatched tokens')

    expect(result).to include("FILE: first.json\nAlpha")
    expect(result).to include("FILE: second.json\nBeta")
  end
end
