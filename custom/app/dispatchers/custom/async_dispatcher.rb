# frozen_string_literal: true

module Custom::AsyncDispatcher
  def listeners
    super + [Custom::FlowListener.instance]
  end
end
