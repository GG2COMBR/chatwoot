# frozen_string_literal: true

class Custom::Api::V1::Kanban::StagesController < Custom::Api::V1::Kanban::BaseController
  before_action :fetch_board
  before_action :fetch_stage, only: %i[update destroy]

  def index
    stages = @board.custom_kanban_stages.order(:position)
    render json: { payload: stages.map { |stg| serialize_stage(stg) } }
  end

  def create
    stage = @board.custom_kanban_stages.new(stage_params)
    stage.account = current_account
    stage.slug = generate_slug(stage.name) if stage.slug.blank?

    if stage.save
      render json: { payload: serialize_stage(stage) }, status: :created
    else
      render json: { error: stage.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def update
    if @stage.update(stage_params)
      render json: { payload: serialize_stage(@stage) }
    else
      render json: { error: @stage.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def destroy
    if @stage.custom_kanban_cards.exists?
      render json: {
        error: 'Não é possível excluir um estágio que possui oportunidades vinculadas. Mova-as antes de excluir.'
      }, status: :unprocessable_entity
      return
    end

    @stage.destroy!
    head :no_content
  end

  def reorder
    stage_ids = params[:stage_ids] || []
    stage_ids.each_with_index do |id, index|
      stage = @board.custom_kanban_stages.find_by(id: id)
      stage&.update(position: index)
    end
    render json: { status: 'success' }
  end

  private

  def fetch_board
    @board = Custom::KanbanBoard.where(account_id: current_account.id).find(params[:kanban_board_id] || params[:board_id])
  end

  def fetch_stage
    @stage = @board.custom_kanban_stages.find(params[:id])
  end

  def stage_params
    params.require(:stage).permit(:name, :slug, :color, :position, :sla_hours, :description)
  end

  def generate_slug(name)
    base = name.to_s.parameterize.underscore
    candidate = base.presence || "stage_#{SecureRandom.hex(3)}"
    counter = 1
    while @board.custom_kanban_stages.exists?(slug: candidate)
      candidate = "#{base}_#{counter}"
      counter += 1
    end
    candidate
  end

  def serialize_stage(stage)
    {
      id: stage.id,
      name: stage.name,
      slug: stage.slug,
      color: stage.color,
      position: stage.position,
      sla_hours: stage.sla_hours,
      description: stage.description,
      cards_count: stage.custom_kanban_cards.count
    }
  end
end
