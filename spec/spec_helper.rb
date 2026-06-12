# frozen_string_literal: true

require 'simplecov'

SimpleCov.start 'rails' do
  add_filter '/bin/'
  add_filter '/config/'
  add_filter '/db/'
  add_filter '/spec/'
end

require 'bundler/setup'
require 'ruby_llm'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/filters'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
    mocks.verify_partial_doubles = true
  end
end
