# frozen_string_literal: true

class RemoveChatStack < ActiveRecord::Migration[8.1]
  def up
    drop_table :messages, if_exists: true, force: :cascade
    drop_table :tool_calls, if_exists: true, force: :cascade
    drop_table :chats, if_exists: true, force: :cascade
    drop_table :models, if_exists: true, force: :cascade
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'chat stack removal is irreversible'
  end
end
