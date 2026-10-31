# 01. Visão Geral da Arquitetura & Isolamento de Upstream

## 1. Princípio Fundamental de Arquitetura

O Chatwoot é um projeto de código aberto em constante evolução, recebendo releases mensais upstream (`v4.18`, `v4.19`, `v4.20`).
Para garantir que a nossa solução de **Visual Flowbuilder**, **Atendimento WhatsApp URA**, **AWS Bedrock** e **Kanban** tenha uma **vida longa sem atrito de merge em upgrades oficiais**, adotamos o **Padrão de Isolamento por Camada `custom/`**.

### Regra de Ouro:
> **É expressamente PROIBIDO modificar arquivos nativos sob as pastas `app/`, `config/` ou `db/` para implementar funcionalidades proprietárias do Flowbuilder.**
> Toda e qualquer classe, controller, model, service, migration ou job do Flowbuilder deve residir estritamente dentro da pasta `custom/`.

---

## 2. A Camada `custom/` e o Autoload Zeitwerk

O Chatwoot nativo possui hooks condicionais (`ChatwootApp.custom?` e `prepend_mod_with`), porém a pasta `custom/` não é carregada no Zeitwerk por padrão.

Para ativar o autoloading de forma autônoma e limpa:
- Criamos o inicializador **`config/initializers/00_custom_loader.rb`**.
- Ele instrui o `Rails.autoloaders.main` a registrar:
  - `custom/app/controllers`
  - `custom/app/models`
  - `custom/app/services`
  - `custom/app/jobs`
  - `custom/app/listeners`
  - `custom/lib`
- Todas as classes vivem sob o namespace Ruby `Custom::` (ex: `Custom::Flows::ExecutionEngine`).

---

## 3. Extensão de Classes Nativas sem Hard Fork (`prepend_mod_with`)

Quando precisarmos estender modelos nativos do Chatwoot (ex: `Conversation`, `Account`, `Team`):
- Criamos um módulo de extensão em `custom/app/models/custom/conversation_extension.rb`.
- Injetamos o comportamento usando o método nativo do Chatwoot:
  ```ruby
  Conversation.prepend_mod_with('Custom::ConversationExtension')
  ```
- Isso garante que qualquer atualização no model nativo `Conversation` continue funcionando sem quebrar nossas adições.

---

## 4. Edição Enterprise & Telemetria

1. **Ativação do Enterprise Edition por Banco de Dados**:
   - Não requer chaves de licença externas nem servidores remotos.
   - O plano é ativado via `InstallationConfig`:
     - `DEPLOYMENT_ENV = 'self-hosted'`
     - `INSTALLATION_PRICING_PLAN = 'enterprise'`
     - `INSTALLATION_PRICING_PLAN_QUANTITY = 1000`
   - Isso libera os recursos Enterprise do Chatwoot (SAML avançado, SLAs, Captain AI, relatórios consolidados).

2. **Bloqueio de Telemetria Externa**:
   - Configurado via variável de ambiente:
     ```bash
     DISABLE_TELEMETRY=true
     ```
   - Impede que qualquer métrica ou dado de conversas seja enviado aos servidores do fabricante (`telemetry.chatwoot.com` / `hub.chatwoot.com`).
   - Toda a observabilidade é **100% privada** via Prometheus, Grafana, Loki e Sentry.
