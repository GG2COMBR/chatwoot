# frozen_string_literal: true

namespace :custom do
  desc 'Popula ambiente neutro GG2 para desenvolvimento e demonstracao'
  task seed: :environment do
    puts '🌱 Iniciando seed do ambiente GG2...'
    result = Custom::SeedService.perform!

    puts "✅ Conta criada/atualizada: #{result[:account].name} (ID: #{result[:account].id})"
    puts "✅ Administrador pronto: #{result[:admin].email}"
    puts "✅ Equipes configuradas: #{result[:teams].map(&:name).join(', ')}"
    puts "✅ Caixa WhatsApp configurada: #{result[:inbox].name} com horários de expediente ativos."
    puts "✅ Fluxo demonstrativo: '#{result[:flow].name}' publicado com sucesso (ID: #{result[:flow].id})."
    puts '🚀 Ambiente GG2 pronto para desenvolvimento e homologação!'
  end
end
