#!/usr/bin/env bash
# =============================================================================
# GG2 Chatwoot Flowbuilder — Script Canônico de Setup & Reinstalação Dev
# =============================================================================
# Uso:
#   bash bin/setup_dev.sh          # Instalação / Atualização idempotente
#   bash bin/setup_dev.sh --reset  # Reinstalação total do zero (recria banco e seeds)
# =============================================================================

set -e

RESET_DB=false
if [ "$1" == "--reset" ]; then
  RESET_DB=true
fi

# Cores para feedback visual
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sem cor

echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}🚀 GG2 Chatwoot Flowbuilder — Setup Automatizado de Desenvolvimento${NC}"
echo -e "${BLUE}====================================================================${NC}"

# 1. Carregar rbenv se presente
if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init -)"
fi

echo -e "\n${BLUE}[1/7] Verificando dependências de sistema...${NC}"
command -v ruby >/dev/null 2>&1 || { echo -e "${RED}❌ Ruby não encontrado!${NC}"; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo -e "${RED}❌ pnpm não encontrado!${NC}"; exit 1; }
echo -e "${GREEN}✓ Ruby $(ruby -v | awk '{print $2}') e pnpm prontos.${NC}"

# 2. Configurar variáveis de ambiente
echo -e "\n${BLUE}[2/7] Configurando variáveis de ambiente...${NC}"
if [ ! -f .env ]; then
  echo -e "${YELLOW}Criando .env a partir de .env.example...${NC}"
  cp .env.example .env
fi

# Garantir DISABLE_TELEMETRY=true
if ! grep -q "DISABLE_TELEMETRY=true" .env; then
  echo -e "${YELLOW}Adicionando DISABLE_TELEMETRY=true ao .env...${NC}"
  echo -e "\nDISABLE_TELEMETRY=true" >> .env
fi

# 3. Preservação Não-Versionada do AWS Bedrock
echo -e "\n${BLUE}[3/7] Verificando credenciais do AWS Bedrock...${NC}"
BEDROCK_LOCAL_FILE="custom/config/bedrock.local.env"
if [ ! -f "$BEDROCK_LOCAL_FILE" ]; then
  if [ -f "custom/config/bedrock.local.env.example" ]; then
    echo -e "${YELLOW}Criando $BEDROCK_LOCAL_FILE a partir do template...${NC}"
    cp custom/config/bedrock.local.env.example "$BEDROCK_LOCAL_FILE"

    # Se o .env atual tiver credenciais ativas do Bedrock, migra para o arquivo local
    ACCESS_KEY=$(grep "^CAPTAIN_BEDROCK_ACCESS_KEY_ID=" .env | cut -d'=' -f2- || true)
    SECRET_KEY=$(grep "^CAPTAIN_BEDROCK_SECRET_ACCESS_KEY=" .env | cut -d'=' -f2- || true)
    REGION=$(grep "^CAPTAIN_BEDROCK_REGION=" .env | cut -d'=' -f2- || true)

    if [ -n "$ACCESS_KEY" ]; then
      sed -i.bak "s|^CAPTAIN_BEDROCK_ACCESS_KEY_ID=.*|CAPTAIN_BEDROCK_ACCESS_KEY_ID=$ACCESS_KEY|" "$BEDROCK_LOCAL_FILE" 2>/dev/null || true
      sed -i.bak "s|^CAPTAIN_BEDROCK_SECRET_ACCESS_KEY=.*|CAPTAIN_BEDROCK_SECRET_ACCESS_KEY=$SECRET_KEY|" "$BEDROCK_LOCAL_FILE" 2>/dev/null || true
      sed -i.bak "s|^CAPTAIN_BEDROCK_REGION=.*|CAPTAIN_BEDROCK_REGION=${REGION:-us-east-1}|" "$BEDROCK_LOCAL_FILE" 2>/dev/null || true
      rm -f "${BEDROCK_LOCAL_FILE}.bak"
      echo -e "${GREEN}✓ Credenciais do Bedrock preservadas em $BEDROCK_LOCAL_FILE${NC}"
    fi
  fi
else
  echo -e "${GREEN}✓ Arquivo não-versionado $BEDROCK_LOCAL_FILE já existe e está seguro.${NC}"
fi

# 4. Instalar dependências
echo -e "\n${BLUE}[4/7] Instalando dependências Ruby e JavaScript...${NC}"
bundle check || bundle install
pnpm install

# 5. Configurar host do Postgres se estiver rodando localmente
DB_HOST="127.0.0.1"
if [ -n "$POSTGRES_HOST" ]; then
  DB_HOST="$POSTGRES_HOST"
fi

# 6. Preparar Banco de Dados
echo -e "\n${BLUE}[5/7] Configurando banco de dados (Host: $DB_HOST)...${NC}"
if [ "$RESET_DB" = true ]; then
  echo -e "${YELLOW}⚠️  Modo --reset ativado: Recriando banco do zero...${NC}"
  POSTGRES_HOST=$DB_HOST bundle exec rails db:drop || true
  POSTGRES_HOST=$DB_HOST bundle exec rails db:create
fi

echo -e "Executando migrações do core e custom..."
POSTGRES_HOST=$DB_HOST bundle exec rails db:migrate

# 7. Executar Seeds Canônicos
echo -e "\n${BLUE}[6/7] Populando banco de dados com fixtures e Enterprise Edition...${NC}"
if [ "$RESET_DB" = true ]; then
  echo -e "Executando rails db:seed (contas nativas)..."
  POSTGRES_HOST=$DB_HOST bundle exec rails db:seed
fi

echo -e "Executando rails custom:seed (Enterprise, Bedrock, Funis Kanban e URA)..."
POSTGRES_HOST=$DB_HOST bundle exec rails custom:seed

# 8. Smoke Test
echo -e "\n${BLUE}[7/7] Executando Smoke Test de Integridade...${NC}"
POSTGRES_HOST=$DB_HOST bundle exec rails runner "
  account = Account.find_by('lower(name) = ?', 'gg2 tecnologia')
  pricing_plan = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value
  boards_count = Custom::KanbanBoard.where(account_id: account.id).count
  stages_count = Custom::KanbanStage.where(account_id: account.id).count
  flows_count = Custom::Flow.where(account_id: account.id).count

  puts '   ✓ Conta: ' + account.name + ' (ID: ' + account.id.to_s + ')'
  puts '   ✓ Plano Enterprise: ' + (pricing_plan == 'enterprise' ? 'ATIVO' : 'INATIVO')
  puts '   ✓ Funis Kanban: ' + boards_count.to_s + ' funil(is) com ' + stages_count.to_s + ' estágios'
  puts '   ✓ Fluxos Flowbuilder: ' + flows_count.to_s + ' fluxo(s) configurado(s)'
"

echo -e "\n${GREEN}====================================================================${NC}"
echo -e "${GREEN}🎉 AMBIENTE INSTALADO COM SUCESSO!${NC}"
echo -e "${GREEN}====================================================================${NC}"
echo -e "Acesse a aplicação com as seguintes credenciais padrão:"
echo -e "   👤 Email: ${YELLOW}admin@gg2.com.br${NC}"
echo -e "   🔑 Senha: ${YELLOW}Password123!${NC}"
echo -e "\nPara iniciar todos os serviços de desenvolvimento:"
echo -e "   👉 ${BLUE}overmind start -f Procfile.dev${NC} ou ${BLUE}pnpm dev${NC}\n"
