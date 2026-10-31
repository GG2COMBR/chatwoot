# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Ai::HandoffDetectorService do
  describe '.human_intent?' do
    it 'returns true for explicit human attendant requests' do
      positive_examples = [
        'Quero falar com um atendente',
        'Por favor, me passe para um humano',
        'Preciso de uma pessoa para me ajudar',
        'chamar atendente',
        'suporte humano por favor',
        'Quero falar com operador',
        'atendente'
      ]

      positive_examples.each do |text|
        expect(described_class.human_intent?(text)).to be(true), "Expected '#{text}' to match human intent"
      end
    end

    it 'returns false for regular questions and commands' do
      negative_examples = [
        'Qual o status do meu pedido?',
        'Segunda via de boleto',
        'Horário de funcionamento',
        'Vocês vendem atacado?',
        'Sim, confirmo',
        'Não',
        ''
      ]

      negative_examples.each do |text|
        expect(described_class.human_intent?(text)).to be(false), "Expected '#{text}' not to match human intent"
      end
    end

    it 'returns false for nil or blank input' do
      expect(described_class.human_intent?(nil)).to be false
      expect(described_class.human_intent?('   ')).to be false
    end
  end
end
