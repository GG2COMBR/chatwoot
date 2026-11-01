# frozen_string_literal: true

class Custom::Api::V1::Kanban::ReasonsController < Custom::Api::V1::Kanban::BaseController
  before_action :fetch_board

  def index
    reasons = @board.custom_kanban_reasons.order(:name)
    render json: {
      payload: reasons.map { |r| { id: r.id, name: r.name, reason_type: r.reason_type } }
    }
  end

  def create
    reason = @board.custom_kanban_reasons.new(reason_params)
    reason.account = current_account

    if reason.save
      render json: { payload: { id: reason.id, name: reason.name, reason_type: reason.reason_type } }, status: :created
    else
      render json: { error: reason.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def destroy
    reason = @board.custom_kanban_reasons.find(params[:id])
    reason.destroy!
    head :no_content
  end

  private

  def fetch_board
    @board = Custom::KanbanBoard.where(account_id: current_account.id).find(params[:kanban_board_id] || params[:board_id])
  end

  def reason_params
    params.require(:reason).permit(:name, :reason_type)
  end
end
