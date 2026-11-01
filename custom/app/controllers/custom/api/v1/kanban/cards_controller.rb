# frozen_string_literal: true

class Custom::Api::V1::Kanban::CardsController < Custom::Api::V1::Kanban::BaseController
  before_action :fetch_board, only: %i[index create]
  before_action :fetch_card, only: %i[show update destroy move]

  def index
    cards = @board.custom_kanban_cards.includes(:contact, :conversation, :assignees, :custom_kanban_stage)
    cards = cards.where(custom_kanban_stage_id: params[:stage_id]) if params[:stage_id].present?
    cards = cards.where(status: params[:status]) if params[:status].present?
    cards = cards.where('title ILIKE ?', "%#{params[:query]}%") if params[:query].present?

    render json: {
      payload: cards.map { |c| serialize_card(c) },
      meta: { total: cards.count }
    }
  end

  def show
    render json: { payload: serialize_card(@card, detailed: true) }
  end

  def create
    card = @board.custom_kanban_cards.new(card_params)
    card.account = current_account

    if card.save
      assign_users(card, params[:assignee_ids]) if params[:assignee_ids].present?
      render json: { payload: serialize_card(card.reload, detailed: true) }, status: :created
    else
      render json: { error: card.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def update
    if @card.update(card_params)
      assign_users(@card, params[:assignee_ids]) if params[:assignee_ids].present?
      render json: { payload: serialize_card(@card.reload, detailed: true) }
    else
      render json: { error: @card.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def move
    new_stage_id = params[:stage_id]
    position = params[:position]

    if new_stage_id.present?
      Custom::Kanban::StageService.move_card!(@card, new_stage_id, position)
      render json: { payload: serialize_card(@card.reload) }
    else
      render json: { error: 'stage_id is required' }, status: :bad_request
    end
  end

  def destroy
    @card.destroy!
    head :no_content
  end

  private

  def fetch_board
    @board = Custom::KanbanBoard.where(account_id: current_account.id).find(params[:kanban_board_id] || params[:board_id])
  end

  def fetch_card
    @card = Custom::KanbanCard.where(account_id: current_account.id).find(params[:id])
  end

  def card_params
    params.require(:card).permit(
      :custom_kanban_stage_id,
      :contact_id,
      :conversation_id,
      :title,
      :description,
      :value,
      :priority,
      :status,
      :custom_kanban_reason_id,
      :position,
      :due_at,
      :scheduled_at
    )
  end

  def assign_users(card, user_ids)
    valid_ids = User.where(id: user_ids).pluck(:id)
    card.custom_kanban_card_assignees.where.not(user_id: valid_ids).destroy_all
    valid_ids.each do |uid|
      card.custom_kanban_card_assignees.find_or_create_by!(user_id: uid, account: current_account)
    end
  end

  def serialize_card(card, detailed: false)
    data = {
      id: card.id,
      board_id: card.custom_kanban_board_id,
      stage_id: card.custom_kanban_stage_id,
      stage_name: card.custom_kanban_stage&.name,
      stage_color: card.custom_kanban_stage&.color,
      title: card.title,
      description: card.description,
      value: card.value.to_f,
      priority: card.priority,
      status: card.status,
      position: card.position,
      due_at: card.due_at,
      scheduled_at: card.scheduled_at,
      stage_entered_at: card.stage_entered_at,
      won_lost_at: card.won_lost_at,
      contact: if card.contact
                 { id: card.contact.id, name: card.contact.name, email: card.contact.email,
                   phone_number: card.contact.phone_number }
               end,
      conversation: if card.conversation
                      { id: card.conversation.id, display_id: card.conversation.display_id,
                        status: card.conversation.status }
                    end,
      assignees: card.assignees.map { |u| { id: u.id, name: u.name, email: u.email } }
    }

    if detailed
      data[:notes] = card.custom_kanban_card_notes.order(created_at: :desc).map do |note|
        { id: note.id, content: note.content, user_name: note.user&.name, created_at: note.created_at }
      end
    end

    data
  end
end
