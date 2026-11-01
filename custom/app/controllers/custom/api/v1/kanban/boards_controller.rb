# frozen_string_literal: true

class Custom::Api::V1::Kanban::BoardsController < Custom::Api::V1::Kanban::BaseController
  before_action :fetch_board, only: %i[show update destroy]

  def index
    boards = current_account_boards.includes(:custom_kanban_stages)
    render json: {
      payload: boards.map { |b| serialize_board(b) }
    }
  end

  def show
    render json: { payload: serialize_board(@board, detailed: true) }
  end

  def create
    board = current_account_boards.new(board_params)
    if board.save
      create_default_stages(board) if board.custom_kanban_stages.empty?
      render json: { payload: serialize_board(board.reload, detailed: true) }, status: :created
    else
      render json: { error: board.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def update
    if @board.update(board_params)
      render json: { payload: serialize_board(@board, detailed: true) }
    else
      render json: { error: @board.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def destroy
    @board.destroy!
    head :no_content
  end

  private

  def current_account_boards
    Custom::KanbanBoard.where(account_id: current_account.id)
  end

  def fetch_board
    @board = current_account_boards.find(params[:id])
  end

  def board_params
    params.require(:board).permit(
      :name,
      :description,
      :position,
      :status_custom_attribute_key,
      :auto_create_cards,
      :inbox_scope,
      :default_stage_id,
      :won_lost_enabled
    )
  end

  def serialize_board(board, detailed: false)
    stages = board.custom_kanban_stages.order(:position).map do |stg|
      {
        id: stg.id,
        name: stg.name,
        slug: stg.slug,
        color: stg.color,
        position: stg.position,
        sla_hours: stg.sla_hours,
        cards_count: detailed ? stg.custom_kanban_cards.count : nil
      }.compact
    end

    {
      id: board.id,
      name: board.name,
      description: board.description,
      position: board.position,
      status_custom_attribute_key: board.status_custom_attribute_key,
      auto_create_cards: board.auto_create_cards,
      inbox_scope: board.inbox_scope,
      default_stage_id: board.default_stage_id,
      won_lost_enabled: board.won_lost_enabled,
      stages: stages,
      cards_count: detailed ? board.custom_kanban_cards.count : nil
    }.compact
  end

  def create_default_stages(board)
    default_stages = [
      { name: 'Lead Qualificado', slug: 'lead_qualificado', position: 0, color: '#3B82F6' },
      { name: 'Orçamento Enviado', slug: 'orcamento_enviado', position: 1, color: '#F59E0B' },
      { name: 'Aguardando Pagamento', slug: 'aguardando_pagamento', position: 2, color: '#8B5CF6' },
      { name: 'Venda Concluída', slug: 'venda_concluida', position: 3, color: '#10B981' }
    ]

    default_stages.each do |stg_data|
      board.custom_kanban_stages.create!(stg_data.merge(account: current_account))
    end
  end
end
