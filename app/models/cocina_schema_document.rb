# frozen_string_literal: true

# Local cache of Cocina schema/relevant docs used for LLM prompt context
class CocinaSchemaDocument < ApplicationRecord
  validates :path, presence: true, uniqueness: true
  validates :content, presence: true
end
