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

  def magento_customer_lookup(payload)
    clean_cpf = sanitize_digits(payload[:cpf])
    found = clean_cpf.present? && clean_cpf != '00000000000'

    {
      status: 'success',
      data: {
        customer_found: found,
        cpf: clean_cpf,
        name: found ? (payload[:name].presence || 'Carlos Eduardo Silva') : nil,
        email: found ? (payload[:email].presence || 'carlos.silva@odontoclinica.com.br') : nil,
        credit_limit: found ? 'R$ 5.000,00' : 'R$ 0,00',
        customer_group: found ? 'Profissional Dentista' : 'Novo Lead'
      }
    }
  end

  def magento_search_products(payload)
    query = payload[:query].to_s.downcase

    products = [
      { sku: 'RES-Z350-A2', name: 'Resina Filtek Z350 XT A2 3M', price: 89.90, stock: 45, unit: 'seringa 4g' },
      { sku: 'ADH-SB2-6ML', name: 'Adesivo Single Bond 2 6ml 3M', price: 95.00, stock: 20, unit: 'frasco' },
      { sku: 'LUV-PROC-M', name: 'Luva de Procedimento Nitrílica M (100un)', price: 34.50, stock: 120, unit: 'cx' },
      { sku: 'ALG-HYDRO-454', name: 'Alginato Hydrogum 5 Zhermack 454g', price: 58.00, stock: 35, unit: 'pct' }
    ]

    filtered = query.present? ? products.select { |p| p[:name].downcase.include?(query) || p[:sku].downcase.include?(query) } : products

    {
      status: 'success',
      data: {
        query: query,
        total: filtered.size,
        products: filtered
      }
    }
  end

  def magento_create_quote(payload)
    cep = sanitize_digits(payload[:cep]).presence || '01310100'
    items_total = (payload[:items_total] || 180.00).to_f
    shipping_cost = cep.start_with?('01', '02', '03') ? 15.00 : 25.00
    grand_total = (items_total + shipping_cost).round(2)

    {
      status: 'success',
      data: {
        quote_id: "Q-#{Time.current.strftime('%y%m%d%H%M')}",
        cep: cep,
        shipping_method: 'Sedex Expresso',
        shipping_cost: format('%.2f', shipping_cost),
        shipping_estimate: '2 dias úteis',
        items_total: format('%.2f', items_total),
        grand_total: format('%.2f', grand_total),
        pix_discount_5pct: format('%.2f', (grand_total * 0.95).round(2))
      }
    }
  end

  def magento_place_order(payload)
    id = "PED-#{Time.current.strftime('%y%m%d')}-#{rand(1000..9999)}"
    amount = payload[:amount] || '195.00'

    {
      status: 'success',
      data: {
        order_id: id,
        status: 'pending_payment',
        amount: amount,
        payment_method: payload[:payment_method] || 'pix',
        pix_code: "00020126580014br.gov.bcb.pix0136gg2-payments-#{id}520400005303986540#{format('%.2f', amount.to_f)}5802BR5913GG2 Odonto6009Sao Paulo62070503***6304ABCD",
        pix_qrcode_url: "https://api.gg2.com.br/pix/qrcode/#{id}.png",
        boleto_url: "https://api.gg2.com.br/boletos/#{id}.pdf",
        expires_at: 30.minutes.from_now.strftime('%H:%M de %d/%m/%Y')
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
      'reseller_balance' => method(:reseller_balance),
      'magento_customer_lookup' => method(:magento_customer_lookup),
      'magento_search_products' => method(:magento_search_products),
      'magento_create_quote' => method(:magento_create_quote),
      'magento_place_order' => method(:magento_place_order)
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
