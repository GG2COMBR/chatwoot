# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Mocks::EcommerceMockService do
  describe '.dispatch' do
    context 'when mock_response is provided' do
      it 'returns custom mock_response directly' do
        result = described_class.dispatch(
          type: 'mock',
          mock_response: { custom_key: 'custom_value' }
        )

        expect(result[:status]).to eq('success')
        expect(result[:data]).to eq('custom_key' => 'custom_value')
      end
    end

    context 'with validate_cpf operation' do
      it 'validates formatted CPF and returns customer data' do
        result = described_class.dispatch(
          operation: 'validate_cpf',
          payload: { cpf: '123.456.789-01' }
        )

        expect(result[:status]).to eq('success')
        expect(result[:data][:cpf]).to eq('12345678901')
        expect(result[:data][:name]).to eq('Maria Oliveira da Silva')
        expect(result[:data][:tier]).to eq('VIP')
        expect(result[:data][:active]).to be true
      end

      it 'returns error on invalid CPF length' do
        result = described_class.dispatch(
          operation: 'validate_cpf',
          payload: { cpf: '123' }
        )

        expect(result[:status]).to eq('error')
        expect(result[:error]).to include('CPF inválido')
      end
    end

    context 'with recent_orders operation' do
      it 'returns mock recent orders list for customer' do
        result = described_class.dispatch(
          operation: 'recent_orders',
          payload: { cpf: '12345678901' }
        )

        expect(result[:status]).to eq('success')
        orders = result[:data][:orders]
        expect(orders).to be_an(Array)
        expect(orders.size).to eq(2)
        expect(orders.first[:order_id]).to eq('PED-9821')
        expect(orders.first[:status]).to eq('Em transporte')
      end
    end

    context 'with order_status operation' do
      it 'returns shipping and tracking information for an order' do
        result = described_class.dispatch(
          operation: 'order_status',
          payload: { order_id: 'PED-4567' }
        )

        expect(result[:status]).to eq('success')
        expect(result[:data][:order_id]).to eq('PED-4567')
        expect(result[:data][:carrier]).to eq('Correios Sedex')
        expect(result[:data][:tracking_url]).to include('BR4567BR')
      end
    end

    context 'with generate_boleto operation' do
      it 'returns barcode and PDF URL for payment' do
        result = described_class.dispatch(
          operation: 'generate_boleto',
          payload: { order_id: 'PED-9821' }
        )

        expect(result[:status]).to eq('success')
        expect(result[:data][:barcode]).to be_present
        expect(result[:data][:pdf_url]).to include('PED-9821.pdf')
        expect(result[:data][:amount]).to eq('R$ 289,90')
      end
    end

    context 'with reseller_balance operation' do
      it 'returns consignor reseller balance and commission tier' do
        result = described_class.dispatch(
          operation: 'reseller_balance',
          payload: { cpf: '12345678901' }
        )

        expect(result[:status]).to eq('success')
        expect(result[:data][:balance_available]).to eq('R$ 1.450,00')
        expect(result[:data][:commission_rate]).to eq('25%')
        expect(result[:data][:reseller_tier]).to eq('Diamante')
      end
    end

    context 'with unknown operation' do
      it 'returns default success mock' do
        result = described_class.dispatch(operation: 'non_existent')

        expect(result[:status]).to eq('success')
        expect(result[:data][:message]).to eq('Mock processed successfully')
      end
    end

    context 'with simulated latency' do
      it 'invokes sleep when latency simulation is requested' do
        service = described_class.new(simulate_latency: true, latency_ms: 100)
        allow(Rails.env).to receive(:test?).and_return(false)
        expect(service).to receive(:sleep).with(0.1)

        service.dispatch
      end
    end
  end
end
