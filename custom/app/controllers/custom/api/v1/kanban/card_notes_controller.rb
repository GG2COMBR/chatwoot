# frozen_string_literal: true

class Custom::Api::V1::Kanban::CardNotesController < Custom::Api::V1::Kanban::BaseController
  before_action :fetch_card

  def index
    notes = @card.custom_kanban_card_notes.includes(:user).order(created_at: :desc)
    render json: {
      payload: notes.map { |n| serialize_note(n) }
    }
  end

  def create
    note = @card.custom_kanban_card_notes.new(note_params)
    note.account = current_account
    note.user = current_user

    if note.save
      render json: { payload: serialize_note(note) }, status: :created
    else
      render json: { error: note.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def destroy
    note = @card.custom_kanban_card_notes.find(params[:id])
    note.destroy!
    head :no_content
  end

  private

  def fetch_card
    @card = Custom::KanbanCard.where(account_id: current_account.id).find(params[:card_id] || params[:kanban_card_id])
  end

  def note_params
    params.require(:note).permit(:content)
  end

  def serialize_note(note)
    {
      id: note.id,
      card_id: note.custom_kanban_card_id,
      content: note.content,
      user_id: note.user_id,
      user_name: note.user&.name,
      created_at: note.created_at
    }
  end
end
