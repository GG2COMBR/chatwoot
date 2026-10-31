# 07. Guia de Promoção Futura para HSB & Troca de Mocks por Live APIs

## 1. Visão Geral da Promoção

O módulo Flowbuilder foi construído sob uma identidade corporativa neutra (**GG2**) e sem dependências duras de infraestrutura proprietária.
Quando o módulo for aprovado para implantação em produção na infraestrutura HSB (junto ao projeto `hsb-chat-ia-v4` e instâncias EC2):

O processo de migração é **plug-and-play** e leva menos de 30 minutos.

---

## 2. Passos para a Promoção

### Passo 1: Transferência da Camada `custom/`
Como 100% do código do Flowbuilder reside em:
- `custom/`
- `config/initializers/00_custom_loader.rb`
- Migrations específicas de `custom_flows`

Basta copiar a pasta `custom/` e o inicializador para a árvore do Chatwoot de destino.

### Passo 2: Execução das Migrations
No Chatwoot de destino:
```bash
RAILS_ENV=production bundle exec rails db:migrate
```

### Passo 3: Troca de Mocks por Live APIs (`hsb-chat-ia-v4`)
Durante o desenvolvimento neutro, a variável `FLOWS_MOCK_ENABLED=true` direciona as consultas de clientes, pedidos e boletos para o `Custom::Mocks::EcommerceMockService`.

Para conectar aos serviços reais do e-commerce (Magento e Linx):
1. No arquivo `.env` de produção:
   ```bash
   FLOWS_MOCK_ENABLED=false
   ECOMMERCE_API_BASE_URL=https://api-gateway.hsb.com.br
   ECOMMERCE_API_TOKEN=prod_token_xyz
   ```
2. O motor do Flowbuilder continuará executando os mesmos nós, chamando os endpoints reais com os mesmos contratos de dados.

---

## 3. Zero Débito Técnico
- Nenhuma referência estática a domínios ou credenciais hardcoded.
- Total conformidade com a LGPD e isolamento multi-tenant por `account_id`.
