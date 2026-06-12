# frozen_string_literal: true

# Abstract base class for dor-services read-only access
class DorServicesRecord < ApplicationRecord
  self.abstract_class = true

  establish_connection :dor_services_read_only

  def self.with_readonly_connection
    ActiveRecord::Base.while_preventing_writes do
      yield connection
    end
  end

  def readonly?
    true
  end
end
