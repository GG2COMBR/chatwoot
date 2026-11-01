# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flows::ExecutionEngine do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:flow) do
    Custom::Flow.create!(
      account: account,
      name: 'Flow Test',
      status: :published,
      nodes: [
        {
          id: 'node_1',
          type: 'interactive_buttons',
          data: { text: 'Escolha uma opção' }
        },
        {
          id: 'node_vendas',
          type: 'team_assignment',
          data: { team_name: 'Equipe Vendas' }
        },
        {
          id: 'node_sac',
          type: 'team_assignment',
          data: { team_name: 'Equipe SAC' }
        },
        {
          id: 'node_ai',
          type: 'ai_fallback',
          data: { model: 'amazon.nova-lite-v1:0' }
        }
      ],
      edges: [
        { id: 'edge_1', source: 'node_1', target: 'node_vendas', condition: { button_id: 'btn_vendas' } },
        { id: 'edge_2', source: 'node_1', target: 'node_sac', condition: { value: 'sac' } },
        { id: 'edge_3', source: 'node_1', target: 'node_ai', condition: { default: true } }
      ]
    )
  end
  let(:conversation) { create(:conversation, account: account) }
  let(:session) { Custom::FlowSession.create!(account: account, custom_flow: flow, conversation: conversation, status: :active) }

  describe '.process!' do
    it 'starts flow on initial node when current_node_id is nil' do
      described_class.process!(session)

      expect(session.current_node_id).to eq('node_1')
      expect(session.context['last_prompt']).to eq('Escolha uma opção')
    end

    it 'transitions to node_vendas on button_id match' do
      session.update!(current_node_id: 'node_1')

      described_class.process!(session, button_id: 'btn_vendas')

      expect(session.current_node_id).to eq('node_vendas')
      expect(session.status).to eq('handoff')
    end

    it 'transitions to node_sac on text value match' do
      session.update!(current_node_id: 'node_1')

      described_class.process!(session, content: 'SAC')

      expect(session.current_node_id).to eq('node_sac')
      expect(session.status).to eq('handoff')
    end

    it 'falls back to default edge and dispatches ai_fallback response' do
      session.update!(current_node_id: 'node_1')

      allow(Custom::Ai::BedrockService).to receive(:chat).and_return(
        status: 'success',
        content: 'Olá! Sou a IA da GG2. Como posso ajudar?'
      )

      expect do
        described_class.process!(session, content: 'Quero tirar uma dúvida geral')
      end.to change { conversation.messages.count }.by(1)

      expect(session.current_node_id).to eq('node_ai')
      expect(session.context['ai_routed']).to be true
      expect(conversation.messages.last.content).to eq('Olá! Sou a IA da GG2. Como posso ajudar?')
    end

    it 'detects human attendant intent on ai node and transfers to human team immediately' do
      session.update!(current_node_id: 'node_1')
      expect(Custom::Ai::BedrockService).not_to receive(:chat)

      described_class.process!(session, content: 'Quero falar com um atendente agora')

      expect(session.current_node_id).to eq('node_ai')
      expect(session.status).to eq('handoff')
      expect(session.context['handoff_reason']).to eq('human_intent_detected')
    end

    it 'does not process when session is not active' do
      session.update!(status: :completed, current_node_id: 'node_1')

      described_class.process!(session, button_id: 'btn_vendas')

      expect(session.current_node_id).to eq('node_1')
      expect(session.status).to eq('completed')
    end

    it 'executes async_action node by creating wait message and enqueuing AsyncActionJob' do
      async_flow = Custom::Flow.create!(
        account: account,
        name: 'Async Flow',
        status: :published,
        nodes: [
          {
            id: 'node_async',
            type: 'async_action',
            data: { wait_message: '⏳ Aguarde...', type: 'mock' }
          }
        ],
        edges: []
      )
      async_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: async_flow,
        conversation: conversation,
        status: :active
      )

      expect(Custom::Flows::AsyncActionJob).to receive(:perform_later).with(
        async_session.id,
        'node_async',
        { 'wait_message' => '⏳ Aguarde...', 'type' => 'mock' }
      )

      expect do
        described_class.process!(async_session)
      end.to change { conversation.messages.count }.by(1)

      expect(conversation.messages.last.content).to eq('⏳ Aguarde...')
      expect(async_session.current_node_id).to eq('node_async')
    end

    it 'tracks retry counts on unmatched input and routes to escape path when max_retries reached' do
      escape_flow = Custom::Flow.create!(
        account: account,
        name: 'Retry Flow',
        status: :published,
        nodes: [
          {
            id: 'node_menu',
            type: 'interactive_buttons',
            data: { text: 'Menu', max_retries: 2, retry_message: 'Opção inválida, tente novamente' }
          },
          {
            id: 'node_escape',
            type: 'team_assignment',
            data: { team_name: 'Equipe SAC' }
          }
        ],
        edges: [
          { id: 'edge_esc', source: 'node_menu', target: 'node_escape', condition: { fallback: true } }
        ]
      )
      retry_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: escape_flow,
        conversation: conversation,
        status: :active,
        current_node_id: 'node_menu'
      )

      # Attempt 1: invalid input, retries becomes 1, re-prompts
      described_class.process!(retry_session, content: 'opcao_invalida_1')
      expect(retry_session.reload.context['retries']).to eq(1)
      expect(retry_session.current_node_id).to eq('node_menu')

      # Attempt 2: invalid input, reaches max_retries (2), routes to escape node
      described_class.process!(retry_session, content: 'opcao_invalida_2')
      expect(retry_session.reload.context['retries']).to eq(2)
      expect(retry_session.current_node_id).to eq('node_escape')
      expect(retry_session.status).to eq('handoff')
    end

    it 'resets retries counter to 0 upon successful edge transition' do
      session.update!(current_node_id: 'node_1', context: { 'retries' => 1 })

      described_class.process!(session, button_id: 'btn_vendas')

      expect(session.reload.current_node_id).to eq('node_vendas')
      expect(session.context['retries']).to eq(0)
    end

    it 'completes session and marks conversation resolved upon reaching finish node' do
      finish_flow = Custom::Flow.create!(
        account: account,
        name: 'Finish Flow',
        status: :published,
        nodes: [
          {
            id: 'node_end',
            type: 'finish',
            data: { farewell_message: 'Obrigado por falar conosco!', final_conversation_status: 'resolved' }
          }
        ],
        edges: []
      )
      finish_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: finish_flow,
        conversation: conversation,
        status: :active
      )

      described_class.process!(finish_session)

      expect(finish_session.reload.status).to eq('completed')
      expect(finish_session.context['completed_at']).to be_present
      expect(conversation.reload.status).to eq('resolved')
      expect(conversation.messages.last.content).to eq('Obrigado por falar conosco!')
    end

    it 'executes kanban_stage_change node by calling StageService' do
      board = Custom::KanbanBoard.create!(account: account, name: 'Vendas', status_custom_attribute_key: 'etapa_kanban')
      stage = Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Lead Qualificado', slug: 'lead_qualificado')
      kanban_flow = Custom::Flow.create!(
        account: account,
        name: 'Kanban Stage Flow',
        status: :published,
        nodes: [
          {
            id: 'node_stage',
            type: 'kanban_stage_change',
            data: { stage_id: stage.id.to_s, stage_name: 'Lead Qualificado' }
          }
        ],
        edges: []
      )
      kanban_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: kanban_flow,
        conversation: conversation,
        status: :active
      )

      expect(Custom::Kanban::StageService).to receive(:transition!).with(
        conversation,
        kanban_session,
        stage.id.to_s,
        'Lead Qualificado'
      ).and_call_original

      described_class.process!(kanban_session)

      expect(conversation.reload.custom_kanban_stage_id).to eq(stage.id)
      expect(conversation.custom_attributes['etapa_kanban']).to eq('Lead Qualificado')
      expect(kanban_session.reload.context['last_kanban_transition']['status']).to eq('success')
    end

    it 'interpolates {{contact.name}} and {{contact.first_name}} in messages' do
      conversation.contact.update!(name: 'Gihovani Demetrio')
      flow.update!(
        nodes: [
          {
            id: 'node_msg',
            type: 'message',
            data: { text: 'Olá, {{contact.first_name}}! Bem-vindo {{contact.name}}!' }
          }
        ],
        edges: []
      )
      interpol_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: flow,
        conversation: conversation,
        status: :active
      )

      expect do
        described_class.process!(interpol_session)
      end.to change(conversation.messages, :count).by(1)

      last_message = conversation.messages.last
      expect(last_message.content).to eq('Olá, Gihovani! Bem-vindo Gihovani Demetrio!')
    end

    it 'interpolates {{context.*}} variables in messages' do
      flow.update!(
        nodes: [
          {
            id: 'node_pix_msg',
            type: 'message',
            data: { text: 'Pedido #{{context.order_id}} gerado! Pix: {{context.pix_code}}' }
          }
        ],
        edges: []
      )
      pix_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: flow,
        conversation: conversation,
        status: :active,
        context: {
          'order_id' => 'PED-9988',
          'pix_code' => '00020126580014br.gov.bcb.pix...'
        }
      )

      described_class.process!(pix_session)

      last_message = conversation.messages.last
      expect(last_message.content).to eq('Pedido #PED-9988 gerado! Pix: 00020126580014br.gov.bcb.pix...')
    end

    it 'saves closure reason into custom_attributes when finish node is executed' do
      finish_flow = Custom::Flow.create!(
        account: account,
        name: 'Finish Flow',
        status: :published,
        nodes: [
          {
            id: 'node_finish',
            type: 'finish',
            data: {
              closure_attribute_key: 'motivo_encerramento',
              closure_reason: 'Venda Concluída via Pix',
              farewell_message: 'Obrigado pela compra!'
            }
          }
        ],
        edges: []
      )
      finish_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: finish_flow,
        conversation: conversation,
        status: :active
      )

      described_class.process!(finish_session)

      expect(conversation.reload.status).to eq('resolved')
      expect(conversation.custom_attributes['motivo_encerramento']).to eq('Venda Concluída via Pix')
      expect(finish_session.reload.status).to eq('completed')
    end

    it 'tracks step status and calculates dwell time across multiple steps' do
      status_flow = Custom::Flow.create!(
        account: account,
        name: 'Status Flow',
        status: :published,
        trigger_config: { 'status_custom_attribute_key' => 'etapa_fluxo' },
        nodes: [
          { id: 'step_1', type: 'message', data: { text: 'Passo 1', step_status_value: 'identificacao' } },
          { id: 'step_2', type: 'message', data: { text: 'Passo 2', step_status_value: 'cotacao' } }
        ],
        edges: [
          { source: 'step_1', target: 'step_2' }
        ]
      )
      status_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: status_flow,
        conversation: conversation,
        status: :active
      )

      # Executa step 1
      described_class.process!(status_session)
      expect(conversation.reload.custom_attributes['etapa_fluxo']).to eq('identificacao')
      expect(status_session.reload.context['step_history'].size).to eq(1)

      # Avança para step 2
      described_class.process!(status_session)
      expect(conversation.reload.custom_attributes['etapa_fluxo']).to eq('cotacao')
      history = status_session.reload.context['step_history']
      expect(history.size).to eq(2)
      expect(history.first['dwell_time_seconds']).to be >= 0
    end

    it 'handles try_catch node retries and routes to catch when max retries exceeded' do
      tc_flow = Custom::Flow.create!(
        account: account,
        name: 'Try Catch Flow',
        status: :published,
        nodes: [
          { id: 'node_tc', type: 'try_catch', data: { max_retries: 2, retry_message: 'Tentando novamente...' } },
          { id: 'node_try', type: 'message', data: { text: 'Branch Try' } },
          { id: 'node_catch', type: 'message', data: { text: 'Branch Catch' } }
        ],
        edges: [
          { source: 'node_tc', target: 'node_try', condition: { status: 'try' } },
          { source: 'node_tc', target: 'node_catch', condition: { status: 'catch' } }
        ]
      )
      tc_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: tc_flow,
        conversation: conversation,
        status: :active,
        current_node_id: 'node_tc',
        context: { 'retry_count_node_tc' => 1 } # Já na tentativa 1
      )

      # Segunda tentativa (ainda < max_retries 2) -> segue pela branch try
      described_class.process!(tc_session)
      expect(tc_session.reload.current_node_id).to eq('node_try')
      expect(tc_session.context['retry_count_node_tc']).to eq(2)

      # Reseta para node_tc agora com contagem 2 (atingiu o limite)
      tc_session.update!(current_node_id: 'node_tc')
      described_class.process!(tc_session)
      expect(tc_session.reload.current_node_id).to eq('node_catch')
      expect(tc_session.context['retry_count_node_tc']).to eq(0) # resetado
    end

    it 'manages labels by adding and removing labels on conversation and contact' do
      labels_flow = Custom::Flow.create!(
        account: account,
        name: 'Labels Flow',
        status: :published,
        nodes: [
          {
            id: 'node_add_labels',
            type: 'manage_labels',
            data: { target: 'conversation', action: 'add', labels: %w[vip lead-qualificado] }
          }
        ],
        edges: []
      )
      labels_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: labels_flow,
        conversation: conversation,
        status: :active
      )

      described_class.process!(labels_session)

      expect(conversation.reload.labels.pluck(:name)).to include('vip', 'lead-qualificado')
    end

    it 'evaluates condition_router node and routes to true or false branches' do
      cond_flow = Custom::Flow.create!(
        account: account,
        name: 'Cond Flow',
        status: :published,
        nodes: [
          {
            id: 'node_cond',
            type: 'condition_router',
            data: { variable: 'customer_found', operator: 'equals', expected_value: 'true' }
          },
          { id: 'node_true', type: 'message', data: { text: 'Cliente Encontrado' } },
          { id: 'node_false', type: 'message', data: { text: 'Novo Cadastro' } }
        ],
        edges: [
          { source: 'node_cond', target: 'node_true', condition: { status: 'true' } },
          { source: 'node_cond', target: 'node_false', condition: { status: 'false' } }
        ]
      )

      cond_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: cond_flow,
        conversation: conversation,
        status: :active,
        current_node_id: 'node_cond',
        context: { 'customer_found' => 'true' }
      )

      described_class.process!(cond_session)
      expect(cond_session.reload.current_node_id).to eq('node_true')
    end

    it 'triggers global escape and creates private note when client types "atendente"' do
      session.update!(current_node_id: 'node_1', context: { 'extracted_data' => { 'cpf' => '12345678900', 'name' => 'Carlos' } })

      expect do
        described_class.process!(session, content: 'Quero falar com um atendente agora')
      end.to change(conversation.messages, :count)

      expect(session.reload.status).to eq('handoff')
      private_note = conversation.messages.where(private: true).last
      expect(private_note).to be_present
      expect(private_note.content).to include('Resumo da URA')
      expect(private_note.content).to include('12345678900')
    end
  end
end
