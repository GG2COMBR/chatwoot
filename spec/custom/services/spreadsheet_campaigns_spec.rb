# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Spreadsheet Campaigns (Bugfix de Duplicação e Fluxo No-Code)', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel) { create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:inbox) { channel.inbox }

  before do
    stub_request(:post, %r{graph\.facebook\.com/.*/messages})
      .to_return(status: 200, body: { messages: [{ id: 'wamid.HBgLM...' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe Custom::Campaigns::Spreadsheet::ContactConversationResolver do
    context 'when contact already has resolved previous conversation' do
      let!(:contact) { create(:contact, account: account, phone_number: '+5511988887777', name: 'Marcos Silva') }
      let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5511988887777') }
      let!(:existing_conversation) do
        create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, status: :resolved)
      end
      let(:campaign) do
        create(:campaign, account: account, inbox: inbox, title: 'Campanha Black Friday', message: 'Olá {{1}}!')
      end

      it 'registra a mensagem dentro da conversa existente sem criar nova conversa' do
        expect do
          described_class.new(
            campaign: campaign,
            phone_number: '+5511988887777',
            name: 'Marcos Silva',
            template_name: 'black_friday',
            wamid: 'wamid.123',
            template_params: { 'processed_params' => { 'body' => { '1' => 'Marcos' } } }
          ).perform
        end.not_to change(Conversation, :count)

        expect(existing_conversation.messages.count).to eq(1)
        campaign_message = existing_conversation.messages.last
        expect(campaign_message.message_type).to eq('template')
        expect(campaign_message.source_id).to eq('wamid.123')
      end

      it 'mantém o status da conversa como resolvida sem abrir na tela dos atendentes' do
        described_class.new(
          campaign: campaign,
          phone_number: '+5511988887777',
          name: 'Marcos Silva',
          template_name: 'black_friday',
          wamid: 'wamid.123',
          template_params: { 'processed_params' => { 'body' => { '1' => 'Marcos' } } }
        ).perform

        expect(existing_conversation.reload.status).to eq('resolved')
      end

      it 'reabre a conversa quando o cliente responde no WhatsApp' do
        described_class.new(
          campaign: campaign,
          phone_number: '+5511988887777',
          name: 'Marcos Silva',
          template_name: 'black_friday',
          wamid: 'wamid.123',
          template_params: { 'processed_params' => { 'body' => { '1' => 'Marcos' } } }
        ).perform

        expect(existing_conversation.reload.status).to eq('resolved')

        # Simulando mensagem de resposta do cliente
        incoming_message = existing_conversation.messages.create!(
          account_id: account.id,
          inbox_id: inbox.id,
          message_type: :incoming,
          content: 'Tenho interesse, como funciona?',
          sender: contact
        )

        expect(incoming_message).to be_present
        expect(existing_conversation.reload.status).to eq('open')
      end
    end

    context 'when contact is new and never interacted' do
      let(:campaign) do
        create(:campaign, account: account, inbox: inbox, title: 'Campanha Prospecção', message: 'Oferta exclusiva')
      end

      it 'cria a conversa com status resolvida para não poluir a fila de atendimento' do
        result = described_class.new(
          campaign: campaign,
          phone_number: '+5511977776666',
          name: 'Cliente Novo',
          template_name: 'prospeccao',
          wamid: 'wamid.999',
          template_params: {}
        ).perform

        conversation = result[:conversation]
        expect(conversation).to be_present
        expect(conversation.status).to eq('resolved')
        expect(conversation.messages.count).to eq(1)
        expect(conversation.messages.first.source_id).to eq('wamid.999')
      end
    end
  end

  describe Custom::Campaigns::Spreadsheet::CsvReaderService do
    it 'detecta separador de ponto e vírgula e normaliza cabeçalhos' do
      csv_text = "Nome;Telefone;Vencimento\nJoão Silva;11987654321;10/11/2026\nMaria;11912345678;15/11/2026"
      reader = described_class.new(csv_text)

      expect(reader.headers).to eq(%w[Nome Telefone Vencimento])
      rows = reader.each_row_with_hash.to_a
      expect(rows.size).to eq(2)
      expect(rows.first.first).to eq({ 'nome' => 'João Silva', 'telefone' => '11987654321', 'vencimento' => '10/11/2026' })
    end

    it 'detecta delimitador de vírgula' do
      csv_text = "name,phone\nCarlos,11999999999"
      reader = described_class.new(csv_text)

      expect(reader.headers).to eq(%w[name phone])
      rows = reader.each_row_with_hash.to_a
      expect(rows.first.first['name']).to eq('Carlos')
    end
  end

  describe Custom::Campaigns::Spreadsheet::RowSenderService do
    let(:campaign) do
      create(:campaign, account: account, inbox: inbox, title: 'Envio Teste', message: 'Olá {{1}}',
                        template_params: {
                          'name' => 'sample_template',
                          'language' => 'pt_BR',
                          'processed_params' => { 'body' => { '1' => 'Nome' } },
                          'spreadsheet_column_mapping' => { '1' => 'nome_cliente' }
                        })
    end
    let(:recipient) do
      Custom::CampaignRecipient.create!(
        campaign: campaign,
        row_number: 2,
        phone_number: '+5511999998888',
        row_data: { 'nome_cliente' => 'Fernanda', 'telefone' => '11999998888' },
        status: 'pending'
      )
    end

    before do
      processor = instance_double(Whatsapp::TemplateProcessorService, call: ['sample_template', 'namespace', 'pt_BR', []])
      allow(Whatsapp::TemplateProcessorService).to receive(:new).and_return(processor)
    end

    it 'envia o template interpolado e marca recipient como sent' do
      result = described_class.new(campaign: campaign, recipient: recipient).perform

      expect(result.success?).to be true
      expect(recipient.reload.status).to eq('sent')
      expect(recipient.message_id).to eq('wamid.HBgLM...')
      expect(Custom::CampaignLog.count).to eq(1)
      expect(Custom::CampaignLog.last.status).to eq('sent')
    end
  end

  describe 'API endpoints de Spreadsheet Campaigns' do
    describe 'POST /api/v1/accounts/:account_id/spreadsheet_campaigns/parse_csv_headers' do
      it 'retorna cabeçalhos e prévia das primeiras linhas' do
        post "/api/v1/accounts/#{account.id}/spreadsheet_campaigns/parse_csv_headers",
             headers: admin.create_new_auth_token,
             params: { csv_text: "Nome,Telefone,Status\nLucas,11988882222,Ativo" }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['headers']).to eq(%w[Nome Telefone Status])
        expect(json['preview'].first.first['nome']).to eq('Lucas')
      end
    end

    describe 'POST /api/v1/accounts/:account_id/spreadsheet_campaigns/send_test' do
      before do
        processor = instance_double(Whatsapp::TemplateProcessorService, call: ['sample', 'ns', 'pt_BR', []])
        allow(Whatsapp::TemplateProcessorService).to receive(:new).and_return(processor)
      end

      it 'envia teste imediato para o WhatsApp do gestor' do
        post "/api/v1/accounts/#{account.id}/spreadsheet_campaigns/send_test",
             headers: admin.create_new_auth_token,
             params: {
               inbox_id: inbox.id,
               phone_number: '+5511999991111',
               template_params: { 'name' => 'sample' }
             }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['wamid']).to be_present
      end
    end
  end
end
