# frozen_string_literal: true

module Custom::Flows::NodeHandlers
  def dispatch_team_assignment(session, node)
    team_id = node.dig(:data, :team_id)
    team_name = node.dig(:data, :team_name)
    team = if team_id.present?
             session.account.teams.find_by(id: team_id)
           elsif team_name.present?
             session.account.teams.where('lower(name) = ?', team_name.to_s.downcase).first
           end

    agent_id = node.dig(:data, :agent_id) || node.dig(:data, :assigned_agent_id)
    agent = session.account.users.find_by(id: agent_id) if agent_id.present?

    config = node[:data] || {}
    result = Custom::Flows::ScheduleEvaluatorService.route_and_handoff!(session.conversation, team, config)

    if result[:open]
      transfer_msg = node.dig(:data, :transfer_message) || node.dig(:data, :text)
      create_outgoing_message(transfer_msg) if transfer_msg.present?
    end

    session.conversation.update!(assignee: agent) if agent && session.conversation

    create_handoff_summary_note(session, 'Transferência de Atendimento')

    session.update!(status: :handoff)
    session.update_context(
      handoff_result: result,
      assigned_team_id: team&.id,
      assigned_agent_id: agent&.id
    )
  end

  def evaluate_business_hours_node(session, node)
    tz = node.dig(:data, :timezone) || 'America/Sao_Paulo'
    is_open = Custom::Flows::ScheduleEvaluatorService.open_now?(node[:data] || session.conversation.inbox, timezone: tz)
    session.update_context(business_hours_open: is_open)
  end

  def dispatch_async_action(session, node)
    wait_message = node.dig(:data, :wait_message) || node.dig(:data, :feedback_message) ||
                   '⏳ Aguarde um instante enquanto consultamos seus dados...'

    session.update_context(last_wait_message: wait_message)
    create_outgoing_message(wait_message)
    Custom::Flows::AsyncActionJob.perform_later(session.id, node[:id], node[:data] || {})
  end

  def dispatch_simple_message(session, node)
    msg_text = node.dig(:data, :text)
    session.update_context(last_message_sent: msg_text)
    create_outgoing_message(msg_text)
  end

  def dispatch_interactive(session, node)
    raw_text = node.dig(:data, :text) || node.dig(:data, :body)
    text = interpolate_variables(raw_text)
    options = node.dig(:data, :buttons) || node.dig(:data, :items) || []
    session.update_context(last_prompt: text)
    return unless session.conversation && text.present?

    Custom::Flows::InteractiveMessageService.dispatch!(session.conversation, text, options)
  end

  def dispatch_ai_fallback(session, node)
    prompt = input_data[:content] || session.context&.dig('last_unmatched_input')
    return trigger_human_handoff(session, node, 'human_intent_detected') if Custom::Ai::HandoffDetectorService.human_intent?(prompt)

    # Suporte a Captura Conversacional de Dados (Slot Filling Multi-turn)
    if node.dig(:data, :extract_slots) == true || node.dig(:data, :required_fields).present?
      return handle_ai_slot_filling(session, node, prompt)
    end

    node_data = (node[:data] || {}).dup
    node_data[:system_prompt] = interpolate_variables(node_data[:system_prompt]) if node_data[:system_prompt].present?

    result = Custom::Ai::BedrockService.chat(prompt, node_data)
    ai_text = result[:content]

    session.update_context(ai_routed: true, ai_result: result, last_ai_query: prompt, last_ai_response: ai_text)
    create_outgoing_message(ai_text)
  end

  def handle_ai_slot_filling(session, node, prompt)
    required = Array(node.dig(:data, :required_fields) || %w[cpf cep]).map(&:to_s)
    current_data = (session.context&.dig('extracted_data') || {}).dup

    # Extração inteligente via heurística direta e LLM
    extracted_now = extract_slots_from_input(prompt.to_s)
    current_data.merge!(extracted_now)
    session.update_context(extracted_data: current_data)

    missing = required.reject { |field| current_data[field].present? }

    if missing.empty?
      session.update_context(slot_filling_status: 'completed')
      confirm_msg = node.dig(:data, :completed_message) || "Perfeito! Dados confirmados. Prosseguindo com seu atendimento..."
      create_outgoing_message(confirm_msg) if confirm_msg.present?
    else
      session.update_context(slot_filling_status: 'in_progress', missing_fields: missing)
      ask_msg = field_prompt_message(missing.first, node)
      create_outgoing_message(ask_msg)
    end
  end

  def extract_slots_from_input(text)
    data = {}
    cpf_match = text.match(/\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/) || text.match(/\b\d{11}\b/)
    data['cpf'] = cpf_match[0].gsub(/\D/, '') if cpf_match

    cep_match = text.match(/\b\d{5}-?\d{3}\b/)
    data['cep'] = cep_match[0].gsub(/\D/, '') if cep_match

    email_match = text.match(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/)
    data['email'] = email_match[0] if email_match

    name_match = text.match(/(?:sou o|sou a|me chamo|nome é)\s+([A-Za-zÀ-ÿ\s]{3,30})/i)
    data['name'] = name_match[1].strip if name_match

    data
  end

  def field_prompt_message(field, node)
    custom_prompts = node.dig(:data, :field_prompts) || {}
    return custom_prompts[field] if custom_prompts[field].present?

    case field
    when 'cpf' then 'Por favor, digite seu CPF ou CNPJ para continuarmos:'
    when 'cep' then 'Por favor, informe seu CEP para calcularmos o frete e prazo:'
    when 'email' then 'Por favor, informe seu e-mail para envio do comprovante:'
    when 'name' then 'Como posso te chamar? Por favor, me diga seu nome completo:'
    else "Por favor, informe seu #{field}:"
    end
  end

  def trigger_human_handoff(session, node, reason)
    team_name = node.dig(:data, :handoff_team) || 'SAC'
    team = session.account.teams.where('lower(name) = ?', team_name.to_s.downcase).first

    config = node[:data] || {}
    result = Custom::Flows::ScheduleEvaluatorService.route_and_handoff!(session.conversation, team, config)
    session.update!(status: :handoff)
    session.update_context(handoff_reason: reason, handoff_result: result)

    create_handoff_summary_note(session, reason)

    handoff_msg = node.dig(:data, :handoff_message) || 'Encaminhando seu atendimento para nossa equipe...'
    create_outgoing_message(handoff_msg)
  end

  def dispatch_kanban_stage_change(session, node)
    stage_id = node.dig(:data, :stage_id) || node.dig(:data, :stage)
    stage_name = node.dig(:data, :stage_name)

    result = Custom::Kanban::StageService.transition!(session.conversation, session, stage_id, stage_name)
    session.update_context(last_kanban_transition: result)
  end

  def finish_node(session, node)
    # 1. Atribuir motivo de encerramento em atributo personalizado caso configurado
    closure_attr_key = node.dig(:data, :closure_attribute_key)
    closure_reason = node.dig(:data, :closure_reason)

    if closure_attr_key.present? && closure_reason.present? && session.conversation
      interpolated_reason = interpolate_variables(closure_reason)
      custom_attrs = (session.conversation.custom_attributes || {}).dup
      custom_attrs[closure_attr_key.to_s] = interpolated_reason
      session.conversation.custom_attributes = custom_attrs
      session.conversation.save!

      session.update_context(
        closure_attribute_key: closure_attr_key,
        closure_reason: interpolated_reason
      )
    end

    msg = node.dig(:data, :text) || node.dig(:data, :farewell_message)
    create_outgoing_message(msg) if msg.present?

    session.update!(status: :completed)
    session.update_context(completed_at: Time.current.iso8601)

    target_status = node.dig(:data, :final_conversation_status)
    if target_status.to_s.downcase == 'snoozed'
      session.conversation&.snoozed!
    else
      session.conversation&.resolved!
    end
  end

  def dispatch_try_catch(session, node)
    node_data = (node[:data] || {}).with_indifferent_access
    max_retries = (node_data[:max_retries] || 3).to_i
    counter_key = "retry_count_#{node[:id]}"
    current_count = (session.context&.dig(counter_key) || 0).to_i

    if current_count < max_retries
      new_count = current_count + 1
      retry_msg = node_data[:retry_message]
      create_outgoing_message(retry_msg) if retry_msg.present?

      session.update_context(
        counter_key => new_count,
        'last_try_catch_status' => 'try',
        'last_retry_count' => new_count
      )
    else
      session.update_context(
        counter_key => 0,
        'last_try_catch_status' => 'catch'
      )
    end
  end

  def dispatch_manage_labels(session, node)
    node_data = (node[:data] || {}).with_indifferent_access
    target = (node_data[:target] || 'conversation').to_s.downcase
    action = (node_data[:action] || 'add').to_s.downcase
    labels = Array(node_data[:labels] || node_data[:label_names])
    return if labels.empty?

    subject = target == 'contact' ? session.conversation&.contact : session.conversation
    return unless subject

    if action == 'remove'
      current = subject.labels.pluck(:name)
      subject.update_labels(current - labels)
    else
      subject.add_labels(labels)
    end

    session.update_context('last_label_action' => { 'target' => target, 'action' => action, 'labels' => labels })
  end

  def dispatch_condition_router(session, node)
    node_data = (node[:data] || {}).with_indifferent_access
    variable_path = node_data[:variable]
    operator = (node_data[:operator] || 'equals').to_s.downcase
    expected_value = node_data[:expected_value].to_s.strip

    actual_value = resolve_variable_value(session, variable_path).to_s.strip
    condition_met = evaluate_condition(actual_value, operator, expected_value)

    result_status = condition_met ? 'true' : 'false'
    session.update_context(
      'last_condition_evaluation' => {
        'variable' => variable_path,
        'actual' => actual_value,
        'operator' => operator,
        'expected' => expected_value,
        'result' => result_status
      }
    )
  end

  def create_handoff_summary_note(session, reason_title)
    return unless session.conversation

    context = session.context || {}
    extracted = context['extracted_data'] || {}
    order_id = context.dig('action_result', 'data', 'order_id') || context['order_id']
    amount = context.dig('action_result', 'data', 'amount') || context['cart_total']

    lines = ["🤖 **[Resumo da URA / Dados Coletados]**", "• **Motivo:** #{reason_title}"]
    lines << "• **Nome:** #{extracted['name'] || session.conversation.contact&.name}" if extracted['name'].present? || session.conversation.contact&.name.present?
    lines << "• **CPF:** #{extracted['cpf']}" if extracted['cpf'].present?
    lines << "• **CEP:** #{extracted['cep']}" if extracted['cep'].present?
    lines << "• **Pedido:** #{order_id}" if order_id.present?
    lines << "• **Valor:** #{amount}" if amount.present?
    lines << "• **Último Nó:** #{session.current_node_id}"

    note_content = lines.join("\n")

    session.conversation.messages.create!(
      account_id: session.account_id,
      inbox_id: session.conversation.inbox_id,
      message_type: :activity,
      private: true,
      content: note_content
    )
  rescue StandardError => e
    Rails.logger.warn("[Custom::Flows::NodeHandlers] Failed to create handoff note: #{e.message}")
  end

  def create_outgoing_message(content)
    return unless session.conversation && content.present?

    interpolated_content = interpolate_variables(content)

    session.conversation.messages.create!(
      account_id: session.account_id,
      inbox_id: session.conversation.inbox_id,
      message_type: :outgoing,
      content: interpolated_content
    )
  end

  def interpolate_variables(text)
    return text if text.blank? || session.conversation.blank?

    contact = session.conversation.contact
    full_name = contact&.name.presence || 'Cliente'
    context = session.context || {}
    action_data = context.dig('action_result', 'data') || {}
    extracted = context['extracted_data'] || {}
    custom_attrs = session.conversation.custom_attributes || {}

    text.to_s.gsub(/\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}/) do |match|
      tag = Regexp.last_match(1)
      case tag
      when 'contact.name' then full_name
      when 'contact.first_name' then full_name.split(/\s+/).first || 'Cliente'
      when 'contact.email' then contact&.email.to_s
      when 'contact.phone_number' then contact&.phone_number.to_s
      when 'account.name' then session.account&.name.to_s
      when /^context\.(.+)/
        sub_key = Regexp.last_match(1)
        action_data[sub_key] || extracted[sub_key] || context[sub_key] || match
      when /^conversation\.custom_attributes\.(.+)/
        sub_key = Regexp.last_match(1)
        custom_attrs[sub_key] || match
      else
        action_data[tag] || extracted[tag] || context[tag] || match
      end
    end
  end

  def resolve_variable_value(session, path)
    return '' if path.blank?

    context = session.context || {}
    action_data = context.dig('action_result', 'data') || {}
    extracted = context['extracted_data'] || {}
    custom_attrs = session.conversation&.custom_attributes || {}

    clean_path = path.to_s.gsub(/[\{\}\s]/, '')

    case clean_path
    when /^context\.(.+)/
      sub = Regexp.last_match(1)
      action_data[sub] || extracted[sub] || context[sub]
    when /^conversation\.custom_attributes\.(.+)/
      sub = Regexp.last_match(1)
      custom_attrs[sub]
    else
      action_data[clean_path] || extracted[clean_path] || context[clean_path] || custom_attrs[clean_path]
    end
  end

  def evaluate_condition(actual, operator, expected)
    case operator
    when 'equals', '=='
      actual.to_s.casecmp(expected.to_s).zero?
    when 'not_equals', '!='
      !actual.to_s.casecmp(expected.to_s).zero?
    when 'contains'
      actual.to_s.downcase.include?(expected.to_s.downcase)
    when 'greater_than', '>'
      actual.to_f > expected.to_f
    when 'less_than', '<'
      actual.to_f < expected.to_f
    when 'is_present', 'present'
      actual.to_s.strip.present?
    when 'is_blank', 'blank'
      actual.to_s.strip.blank?
    else
      actual.to_s == expected.to_s
    end
  end
end
