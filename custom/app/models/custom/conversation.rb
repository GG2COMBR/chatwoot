# frozen_string_literal: true

module Custom::Conversation
  def list_of_keys
    super + %w[custom_kanban_stage_id]
  end
end
