# frozen_string_literal: true

class CreateCocinaSchemaDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :cocina_schema_documents do |t|
      t.string :path, null: false
      t.text :content, null: false
      t.string :source, null: false, default: 'sul-dlss/cocina-models'
      t.string :digest

      t.timestamps
    end

    add_index :cocina_schema_documents, :path, unique: true
  end
end
