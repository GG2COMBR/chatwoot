# frozen_string_literal: true

class Custom::Api::V1::FlowsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_flow, only: [:show, :update, :destroy, :publish, :duplicate]

  def index
    flows = current_account_flows.order(updated_at: :desc)
    flows = flows.where(status: params[:status]) if params[:status].present?
    flows = flows.where('name ILIKE ?', "%#{params[:query]}%") if params[:query].present?

    render json: {
      payload: flows.map { |flow| serialize_flow_summary(flow) },
      meta: { count: flows.count }
    }
  end

  def show
    render json: { payload: serialize_flow_detail(@flow) }
  end

  def create
    flow = current_account_flows.new(flow_params)
    flow.status = :draft

    if flow.save
      render json: { payload: serialize_flow_detail(flow) }, status: :created
    else
      render json: { error: flow.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def update
    if @flow.update(flow_params)
      render json: { payload: serialize_flow_detail(@flow) }
    else
      render json: { error: @flow.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def destroy
    @flow.destroy!
    head :no_content
  end

  def publish
    validation = validate_flow_integrity(@flow)
    if validation[:valid]
      @flow.update!(status: :published)
      render json: { payload: serialize_flow_detail(@flow), message: 'Flow published successfully' }
    else
      render json: { error: validation[:error] }, status: :unprocessable_entity
    end
  end

  def duplicate
    cloned_flow = @flow.dup
    cloned_flow.name = "#{@flow.name} (Cópia)"
    cloned_flow.status = :draft
    cloned_flow.save!

    render json: { payload: serialize_flow_detail(cloned_flow) }, status: :created
  end

  def kanban_options
    account_boards = Custom::KanbanBoard.where(account_id: Current.account.id).includes(:custom_kanban_stages)

    boards = account_boards.map do |board|
      {
        id: board.id.to_s,
        name: board.name,
        status_custom_attribute_key: board.status_custom_attribute_key,
        stages: board.custom_kanban_stages.map do |stg|
          { id: stg.id.to_s, name: stg.name, slug: stg.slug, color: stg.color }
        end
      }
    end

    render json: { payload: { funnels: boards } }
  rescue StandardError => e
    Rails.logger.warn("[Custom::Api::V1::FlowsController] kanban_options error: #{e.message}")
    render json: { payload: { funnels: [] } }
  end

  private

  def current_account_flows
    Custom::Flow.where(account_id: Current.account.id)
  end

  def fetch_flow
    @flow = current_account_flows.find(params[:id])
  end

  def flow_params
    permitted = params.require(:custom_flow).permit(:name, :description, :trigger_type)
    extract_json_structures!(permitted)
    permitted
  end

  def extract_json_structures!(permitted)
    raw_flow = params[:custom_flow] || {}
    permitted[:trigger_config] = raw_flow[:trigger_config].to_unsafe_h if raw_flow[:trigger_config].respond_to?(:to_unsafe_h)
    permitted[:nodes] = sanitize_elements(raw_flow[:nodes]) if raw_flow[:nodes].is_a?(Array)
    permitted[:edges] = sanitize_elements(raw_flow[:edges]) if raw_flow[:edges].is_a?(Array)
  end

  def sanitize_elements(elements)
    elements.map { |item| item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item }
  end

  def validate_flow_integrity(flow)
    nodes = flow.nodes || []
    return { valid: false, error: 'O fluxo precisa conter pelo menos um nó.' } if nodes.empty?
    return { valid: false, error: 'O fluxo precisa conter um nó inicial (start).' } unless start_node_present?(nodes)

    { valid: true }
  end

  def start_node_present?(nodes)
    nodes.any? do |node|
      n = node.with_indifferent_access
      n[:type] == 'start' || n[:id] == 'start'
    end
  end

  def serialize_flow_summary(flow)
    {
      id: flow.id,
      name: flow.name,
      description: flow.description,
      status: flow.status,
      trigger_type: flow.trigger_type,
      nodes_count: (flow.nodes || []).size,
      linked_automation_rules_count: find_linked_automation_rules(flow.id).size,
      updated_at: flow.updated_at
    }
  end

  def serialize_flow_detail(flow)
    {
      id: flow.id,
      name: flow.name,
      description: flow.description,
      status: flow.status,
      trigger_type: flow.trigger_type,
      trigger_config: flow.trigger_config,
      status_custom_attribute_key: flow.trigger_config&.dig('status_custom_attribute_key'),
      linked_automation_rules: find_linked_automation_rules(flow.id),
      nodes: flow.nodes,
      edges: flow.edges,
      created_at: flow.created_at,
      updated_at: flow.updated_at
    }
  end

  def find_linked_automation_rules(flow_id)
    rules = AutomationRule.where(account_id: Current.account.id).select do |rule|
      rule_triggers_flow?(rule, flow_id)
    end
    rules.map { |r| format_linked_rule(r) }
  end

  def rule_triggers_flow?(rule, flow_id)
    (rule.actions || []).any? do |action|
      act = action.with_indifferent_access
      act[:action_name] == 'trigger_flow' && act[:action_params]&.map(&:to_i)&.include?(flow_id.to_i)
    end
  end

  def format_linked_rule(rule)
    {
      id: rule.id,
      name: rule.name,
      active: rule.active,
      event_name: rule.event_name
    }
  end
end
