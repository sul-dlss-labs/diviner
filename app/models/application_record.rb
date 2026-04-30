# frozen_string_literal: true

# Base class for all DB models in the application
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
