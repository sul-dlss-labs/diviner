# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm'
require_relative '../../../app/tools/model_tool'
require_relative '../../../app/tools/url_fetch_tool'
require_relative '../../../app/agents/diviner/report_agent'

RSpec.describe Diviner::ReportAgent do
  describe '.instructions' do
    it 'captures the broadened SQL planning guidance' do
      instructions = described_class.instructions

      expect(instructions).to include('Prefer a two-phase shape: filtered CTE first, grouped/aggregated result second.')
      expect(instructions).to include('When using recursive descent with .**, prefer strict JSON path mode.')
      expect(instructions).to include('Push filtering, grouping, deduplication, and anomaly detection into SQL rather than relying on Ruby post-processing.')
      expect(instructions).to include('Common report families are metadata validation, catalog-link consistency, descriptive metadata anomalies, and structural file metrics.')
    end
  end
end
