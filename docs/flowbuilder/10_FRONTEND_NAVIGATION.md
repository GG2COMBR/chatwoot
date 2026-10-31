# 10. Navegação e Lista Administrativa do Flowbuilder

## 1. Visão Geral

O Flowbuilder está integrado à navegação administrativa nativa do Chatwoot (`Configurações > Flowbuilder`), permitindo aos administradores da conta gerenciar visualmente todos os fluxos conversacionais ativos, rascunhos e modelos.

- **Rota no Navegador**: `/app/accounts/:accountId/settings/custom_flows/list`
- **Permissão de Acesso**: Restrito a administradores (`role: administrator`).

---

## 2. Componentes da Interface

1. **Item no Menu Lateral (`Sidebar.vue`)**:
   - Ícone: `i-lucide-git-branch`
   - Rótulo: `Flowbuilder` (chave i18n `SIDEBAR.FLOWBUILDER`)
   - Posicionamento: Agrupado na seção de configurações junto a Automação e Bots.

2. **Página de Listagem (`customFlows/Index.vue`)**:
   - Cabeçalho padronizado (`BaseSettingsHeader`) com título e descrição.
   - Barra de busca instantânea por nome ou descrição do fluxo.
   - Filtros rápidos por status: `Todos`, `Publicados`, `Rascunhos`.
   - Badges de identificação de gatilho (`WhatsApp Padrão`, `Gatilho Kanban`).
   - Ações de gerenciamento:
     - **Editar Canvas**: Abre o editor visual com zoom e minimapa.
     - **Duplicar**: Cria uma cópia independente em status de rascunho com sufixo `(Cópia)`.
     - **Excluir**: Confirmação modal e remoção segura via API.

3. **Modal de Criação**:
   - Criação ágil com nome, descrição e gatilho de disparo.
   - Redirecionamento automático para a área de desenho após criação.
