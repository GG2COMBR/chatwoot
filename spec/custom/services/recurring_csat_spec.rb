# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Recurring CSAT Survey', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, csat_survey_enabled: true) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact) }
  let(:agent_joao) { create(:user, account: account, role: :agent, name: 'João') }
  let(:agent_bruna) { create(:user, account: account, role: :agent, name: 'Bruna') }

  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, assignee: agent_joao)
  end

  before do
    # Mensagem de entrada inicial do cliente
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'Olá!')
  end

  describe 'CsatSurveyService recorrência' do
    it 'dispara pesquisa CSAT na primeira resolução do atendimento' do
      conversation.resolved!
      expect(CsatSurveyService.new(conversation: conversation).perform).to be_truthy

      csat_message = conversation.messages.where(content_type: :input_csat).last
      expect(csat_message).to be_present
      expect(csat_message.content_attributes['assigned_agent_id']).to eq(agent_joao.id)
    end

    it 'não reenvia CSAT se a conversa for resolvida novamente sem novas mensagens do cliente' do
      conversation.resolved!
      CsatSurveyService.new(conversation: conversation).perform
      expect(conversation.messages.where(content_type: :input_csat).count).to eq(1)

      # Desresolve e resolve de novo sem mensagens do cliente
      conversation.open!
      conversation.resolved!
      CsatSurveyService.new(conversation: conversation).perform
      expect(conversation.messages.where(content_type: :input_csat).count).to eq(1)
    end

    it 'dispara novo CSAT quando o cliente volta a chamar semanas depois e o atendimento é resolvido por outra atendente' do
      # 1º Atendimento com João
      conversation.resolved!
      CsatSurveyService.new(conversation: conversation).perform
      first_csat = conversation.messages.where(content_type: :input_csat).last

      # Cliente responde à primeira pesquisa
      first_csat.content_attributes['submitted_values'] = {
        'csat_survey_response' => { 'rating' => 5, 'feedback_message' => 'Ótimo atendimento do João' }
      }
      first_csat.save!
      CsatSurveys::ResponseBuilder.new(message: first_csat).perform

      first_response = CsatSurveyResponse.find_by(message_id: first_csat.id)
      expect(first_response.assigned_agent_id).to eq(agent_joao.id)

      # Semanas depois: cliente envia nova dúvida e Bruna assume o atendimento
      conversation.open!
      conversation.update!(assignee: agent_bruna)
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'Preciso de mais ajuda!')

      # Bruna resolve o chamado
      conversation.resolved!
      CsatSurveyService.new(conversation: conversation).perform

      expect(conversation.messages.where(content_type: :input_csat).count).to eq(2)
      second_csat = conversation.messages.where(content_type: :input_csat).last
      expect(second_csat.id).not_to eq(first_csat.id)
      expect(second_csat.content_attributes['assigned_agent_id']).to eq(agent_bruna.id)

      # Cliente responde à segunda pesquisa
      second_csat.content_attributes['submitted_values'] = {
        'csat_survey_response' => { 'rating' => 4, 'feedback_message' => 'Muito bom Bruna' }
      }
      second_csat.save!
      CsatSurveys::ResponseBuilder.new(message: second_csat).perform

      second_response = CsatSurveyResponse.find_by(message_id: second_csat.id)
      expect(second_response.assigned_agent_id).to eq(agent_bruna.id)
    end
  end

  describe 'Public CSAT API com múltiplas pesquisas históricas' do
    it 'carrega a pesquisa CSAT mais recente da conversa' do
      conversation.resolved!
      CsatSurveyService.new(conversation: conversation).perform
      conversation.messages.where(content_type: :input_csat).last

      conversation.open!
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'Nova dúvida')
      conversation.resolved!
      CsatSurveyService.new(conversation: conversation).perform
      second_csat = conversation.messages.where(content_type: :input_csat).last

      get "/public/api/v1/csat_survey/#{conversation.uuid}"
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['id']).to eq(second_csat.id)
    end
  end
end
