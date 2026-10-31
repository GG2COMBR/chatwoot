# frozen_string_literal: true

class Custom::Mocks::EcommerceMockService
  MOCK_BARCODE = '34191.79001 01043.510047 91020.150008 5 99990000028990'
  SAMPLE_ORDERS = [
    {
      order_id: 'PED-9821',
      status: 'Em transporte',
      tracking_code: 'BR123456789BR',
      total: 'R$ 289,90',
      date: '2026-10-28'
    },
    {
      order_id: 'PED-9102',
      status: 'Entregue',
      tracking_code: 'BR987654321BR',
      total: 'R$ 149,00',
      date: '2026-09-15'
    }
  ].freeze

  def self.dispatch(config)
    new(config).dispatch
  end

  def initialize(config = {})
    @config = (config || {}).with_indifferent_access
  end

  def dispatch
    simulate_latency! if should_simulate_latency?

    return { status: 'success', data: @config[:mock_response] } if @config[:mock_response].present?

    operation = (@config[:operation] || 'default').to_s.downcase
    payload = (@config[:payload] || @config[:data] || {}).with_indifferent_access

    handler = operation_handlers[operation] || method(:default_mock_response)
    handler.call(payload)
  end

  def validate_cpf(payload)
    clean_cpf = sanitize_digits(payload[:cpf])
    return { status: 'error', error: 'CPF inválido. Deve conter 11 dígitos numéricos.' } if clean_cpf.length != 11

    {
      status: 'success',
      data: {
        cpf: clean_cpf,
        name: 'Maria Oliveira da Silva',
        tier: 'VIP',
        active: true,
        created_at: '2024-03-12'
      }
    }
  end

  def recent_orders(payload)
    clean_cpf = sanitize_digits(payload[:cpf])

    {
      status: 'success',
      data: {
        cpf: clean_cpf,
        orders: SAMPLE_ORDERS
      }
    }
  end

  def order_status(payload)
    id = payload[:order_id].presence || 'PED-9821'

    {
      status: 'success',
      data: {
        order_id: id,
        status: 'Em transporte',
        carrier: 'Correios Sedex',
        tracking_code: "BR#{id.to_s.gsub(/\D/, '')}BR",
        delivery_estimate: '2 dias úteis',
        tracking_url: "https://rastreamento.correios.com.br/app/index.php?codigo=BR#{id.to_s.gsub(/\D/, '')}BR"
      }
    }
  end

  def generate_boleto(payload)
    id = payload[:order_id].presence || 'PED-9821'

    {
      status: 'success',
      data: {
        order_id: id,
        barcode: MOCK_BARCODE,
        pdf_url: "https://faturas.gg2.com.br/boletos/#{id}.pdf",
        expires_at: 3.days.from_now.strftime('%d/%m/%Y'),
        amount: 'R$ 289,90'
      }
    }
  end

  def reseller_balance(payload)
    clean_cpf = sanitize_digits(payload[:cpf])

    {
      status: 'success',
      data: {
        cpf: clean_cpf,
        balance_available: 'R$ 1.450,00',
        balance_pending: 'R$ 320,00',
        commission_rate: '25%',
        next_settlement: '05/11/2026',
        reseller_tier: 'Diamante'
      }
    }
  end

  private

  def operation_handlers
    {
      'validate_cpf' => method(:validate_cpf),
      'customer_by_cpf' => method(:validate_cpf),
      'recent_orders' => method(:recent_orders),
      'order_status' => method(:order_status),
      'generate_boleto' => method(:generate_boleto),
      'reseller_balance' => method(:reseller_balance)
    }
  end

  def default_mock_response(_payload)
    { status: 'success', data: { message: 'Mock processed successfully', timestamp: Time.current.iso8601 } }
  end

  def sanitize_digits(value)
    value.to_s.gsub(/\D/, '')
  end

  def should_simulate_latency?
    return false if Rails.env.test?

    @config[:simulate_latency] == true || ENV['FLOWS_MOCK_SIMULATE_LATENCY'] == 'true'
  end

  def simulate_latency!
    latency_ms = (@config[:latency_ms] || ENV.fetch('FLOWS_MOCK_LATENCY_MS', 300)).to_i
    sleep(latency_ms / 1000.0) if latency_ms.positive?
  end
end
