<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineOptions({
  name: 'BlockCatalog',
});

const emit = defineEmits(['add-node']);

const availableBlocks = [
  {
    type: 'message',
    label: 'Enviar Mensagem',
    icon: 'i-lucide-message-square',
    color: 'hover:border-blue-500/50 hover:bg-blue-500/5 text-blue-600 dark:text-blue-400',
    defaultData: { label: 'Enviar Mensagem', text: 'Olá! Como posso ajudar você?' },
  },
  {
    type: 'interactive_buttons',
    label: 'Pergunta com Botões',
    icon: 'i-lucide-list',
    color: 'hover:border-amber-500/50 hover:bg-amber-500/5 text-amber-600 dark:text-amber-400',
    defaultData: {
      label: 'Pergunta com Botões',
      body: 'Selecione uma opção:',
      buttons: [
        { id: 'btn_1', title: 'Opção 1' },
        { id: 'btn_2', title: 'Opção 2' },
      ],
    },
  },
  {
    type: 'interactive_list',
    label: 'Lista de Opções WhatsApp',
    icon: 'i-lucide-list-filter',
    color: 'hover:border-emerald-500/50 hover:bg-emerald-500/5 text-emerald-600 dark:text-emerald-400',
    defaultData: {
      label: 'Lista de Opções WhatsApp',
      body: 'Por favor, escolha como posso te ajudar hoje:',
      button_text: 'Escolha uma opção',
      items: [
        { id: 'compras', title: 'Compras e Orçamentos', description: 'Fazer compras, cotações e orçamentos' },
        { id: 'duvida_produto', title: 'Dúvida técnica - Produto', description: 'Informações técnicas do produto' },
        { id: 'pedidos_suporte', title: 'Meus Pedidos e Suporte', description: 'Acompanhar pedido, 2ª via, notas fiscais, trocas' },
        { id: 'acesso_cadastro', title: 'Acesso e Cadastro', description: 'Atualizar e-mail, telefone, token ou dados' },
        { id: 'politica_seguranca', title: 'Política e Segurança', description: 'Conhecer nossas políticas de privacidade' },
        { id: 'encerrar', title: 'Encerrar Atendimento', description: 'Finalizar o chat e encerrar o atendimento' },
      ],
    },
  },
  {
    type: 'business_hours',
    label: 'Horário de Atendimento',
    icon: 'i-lucide-clock',
    color: 'hover:border-blue-600/50 hover:bg-blue-600/5 text-blue-700 dark:text-blue-300',
    defaultData: {
      label: 'Checar Horário',
      offline_message: 'Nosso expediente encerrou. Retornaremos em breve!',
    },
  },
  {
    type: 'ai_fallback',
    label: 'Assistente IA (Multi-LLM)',
    icon: 'i-lucide-sparkles',
    color: 'hover:border-purple-500/50 hover:bg-purple-500/5 text-purple-600 dark:text-purple-400',
    defaultData: {
      label: 'Assistente IA',
      provider: 'bedrock',
      model: 'amazon.nova-lite-v1:0',
      temperature: 0.3,
      max_tokens: 300,
      system_prompt: 'Você é um assistente virtual gentil e prestativo da GG2.',
    },
  },
  {
    type: 'human_transfer',
    label: 'Transferir Atendente',
    icon: 'i-lucide-user-check',
    color: 'hover:border-teal-500/50 hover:bg-teal-500/5 text-teal-600 dark:text-teal-400',
    defaultData: {
      label: 'Transferir Atendente',
      transfer_message: 'Um momento, estou transferindo você para um atendente...',
    },
  },
  {
    type: 'kanban_stage_change',
    label: 'Mover no Kanban',
    icon: 'i-lucide-columns-3',
    color: 'hover:border-indigo-500/50 hover:bg-indigo-500/5 text-indigo-600 dark:text-indigo-400',
    defaultData: {
      label: 'Mover no Kanban',
      stage_id: 'lead_qualificado',
      stage_name: 'Lead Qualificado',
    },
  },
  {
    type: 'async_api',
    label: 'Consulta ERP / Mocks',
    icon: 'i-lucide-database',
    color: 'hover:border-cyan-500/50 hover:bg-cyan-500/5 text-cyan-600 dark:text-cyan-400',
    defaultData: {
      label: 'Consulta de Dados',
      operation: 'consultar_cpf',
      wait_message: '⏳ Aguarde um instante enquanto consultamos nossos sistemas...',
    },
  },
  {
    type: 'finish',
    label: 'Encerrar Conversa',
    icon: 'i-lucide-check-circle',
    color: 'hover:border-rose-500/50 hover:bg-rose-500/5 text-rose-600 dark:text-rose-400',
    defaultData: {
      label: 'Encerrar Conversa',
      farewell_message: 'Obrigado por falar conosco! Até breve.',
    },
  },
];

const handleAdd = block => {
  emit('add-node', {
    type: block.type,
    data: JSON.parse(JSON.stringify(block.defaultData || {})),
  });
};
</script>

<template>
  <div class="absolute top-4 left-4 z-20 w-64 bg-n-solid-1/95 backdrop-blur-md rounded-2xl border border-n-strong shadow-xl p-3 flex flex-col gap-2 select-none">
    <div class="flex items-center gap-2 px-2 py-1">
      <Icon icon="i-lucide-layout-grid" class="size-4 text-n-brand" />
      <span class="text-xs font-semibold text-n-slate-12">Catálogo de Blocos</span>
    </div>

    <div class="grid grid-cols-1 gap-1 max-h-[calc(100vh-220px)] overflow-y-auto">
      <button
        v-for="block in availableBlocks"
        :key="block.type"
        type="button"
        class="flex items-center gap-2.5 px-3 py-2 rounded-xl border border-transparent text-left transition-all duration-150 cursor-pointer active:scale-[0.98] group"
        :class="block.color"
        @click.stop="handleAdd(block)"
      >
        <div class="size-6 rounded-lg bg-n-alpha-2 flex items-center justify-center shrink-0">
          <Icon :icon="block.icon" class="size-3.5" />
        </div>
        <div class="flex flex-col truncate">
          <span class="text-xs font-medium text-n-slate-12 group-hover:text-n-brand transition-colors truncate">
            {{ block.label }}
          </span>
        </div>
      </button>
    </div>
  </div>
</template>
