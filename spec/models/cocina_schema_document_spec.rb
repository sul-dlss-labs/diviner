# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CocinaSchemaDocument do
  it 'validates presence and uniqueness of path' do
    described_class.create!(path: 'schema.json', content: '{}')

    duplicate = described_class.new(path: 'schema.json', content: '{}')
    missing_path = described_class.new(content: '{}')
    missing_content = described_class.new(path: 'other.json')

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:path]).to include('has already been taken')
    expect(missing_path).not_to be_valid
    expect(missing_path.errors[:path]).to include("can't be blank")
    expect(missing_content).not_to be_valid
    expect(missing_content.errors[:content]).to include("can't be blank")
  end
end
