# frozen_string_literal: true

namespace :custom do
  desc 'Popula ambiente GG2 para desenvolvimento e demonstracao (WITH_DEMO=true|false)'
  task seed: :environment do
    with_demo = ENV['WITH_DEMO'].nil? || %w[true 1 yes].include?(ENV['WITH_DEMO'].to_s.downcase)
    mode_text = with_demo ? 'completo (com fluxos e dados de demonstração)' : 'mínimo limpo (sem dados de demonstração)'
    puts "🌱 Iniciando seed do ambiente GG2 no modo #{mode_text}..."
    result = Custom::SeedService.perform!(with_demo: with_demo)

    puts "✅ Conta criada/atualizada: #{result[:account].name} (ID: #{result[:account].id})"
    puts "✅ Administrador pronto: #{result[:admin].email}"
    if with_demo
      puts "✅ Equipes configuradas: #{result[:teams].map(&:name).join(', ')}"
      puts "✅ Caixa WhatsApp configurada: #{result[:inbox].name} com horários de expediente ativos."
      puts "✅ Fluxo demonstrativo: '#{result[:flow]&.name}' publicado com sucesso (ID: #{result[:flow]&.id})."
    else
      puts '✅ Ambiente configurado em modo limpo (sem agentes extras, sem caixas de teste e sem fluxos de demonstração).'
    end
    puts '🚀 Ambiente GG2 pronto para desenvolvimento e homologação!'
  end
end
