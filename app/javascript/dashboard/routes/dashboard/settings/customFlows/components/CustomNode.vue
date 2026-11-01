<script setup>
import { computed } from 'vue';
import { Handle, Position } from '@vue-flow/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineOptions({
  name: 'CustomFlowNode',
});

const props = defineProps({
  id: {
    type: String,
    required: true,
  },
  type: {
    type: String,
    required: true,
  },
  data: {
    type: Object,
    default: () => ({}),
  },
  selected: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['delete']);

const nodeMeta = computed(() => {
  switch (props.type) {
    case 'start':
      return {
        label: 'Início da Conversa',
        icon: 'i-lucide-play',
        color: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/30',
        hasTarget: false,
        hasSource: true,
      };
    case 'interactive_buttons':
    case 'interactive_list':
      return {
        label: props.type === 'interactive_list' ? 'Lista Interativa' : 'Pergunta com Botões',
        icon: 'i-lucide-list',
        color: 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/30',
        hasTarget: true,
        hasSource: true,
      };
    case 'business_hours':
      return {
        label: 'Horário de Atendimento',
        icon: 'i-lucide-clock',
        color: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-500/30',
        hasTarget: true,
        hasSource: true,
      };
    case 'ai_fallback':
    case 'ai_agent':
      return {
        label: 'Assistente IA (LLM)',
        icon: 'i-lucide-sparkles',
        color: 'bg-purple-500/10 text-purple-600 dark:text-purple-400 border-purple-500/30',
        hasTarget: true,
        hasSource: true,
      };
    case 'human_transfer':
      return {
        label: 'Transferir para Atendente',
        icon: 'i-lucide-user-check',
        color: 'bg-teal-500/10 text-teal-600 dark:text-teal-400 border-teal-500/30',
        hasTarget: true,
        hasSource: true,
      };
    case 'kanban_stage_change':
      return {
        label: 'Mover Estágio no Kanban',
        icon: 'i-lucide-columns-3',
        color: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border-indigo-500/30',
        hasTarget: true,
        hasSource: true,
      };
    case 'async_api':
      return {
        label: 'Consulta Externa / ERP',
        icon: 'i-lucide-database',
        color: 'bg-cyan-500/10 text-cyan-600 dark:text-cyan-400 border-cyan-500/30',
        hasTarget: true,
        hasSource: true,
      };
    case 'finish':
      return {
        label: 'Encerrar Conversa (CSAT)',
        icon: 'i-lucide-check-circle',
        color: 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-500/30',
        hasTarget: true,
        hasSource: false,
      };
    case 'message':
    default:
      return {
        label: 'Enviar Mensagem',
        icon: 'i-lucide-message-square',
        color: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-500/30',
        hasTarget: true,
        hasSource: true,
      };
  }
});

const nodePreview = computed(() => {
  if (props.type === 'ai_fallback' || props.type === 'ai_agent') {
    const prov = props.data?.provider || 'bedrock';
    const mdl = props.data?.model === 'custom' && props.data?.custom_model ? props.data.custom_model : (props.data?.model || 'amazon.nova-lite-v1:0');
    return `IA [${prov}]: ${mdl}`;
  }
  if (props.type === 'human_transfer') {
    const teamName = props.data?.team_name || (props.data?.team_id ? `Equipe #${props.data.team_id}` : null);
    const agentName = props.data?.agent_name || (props.data?.assigned_agent_id ? `Atendente #${props.data.assigned_agent_id}` : null);
    if (teamName && agentName) return `Destino: ${teamName} • ${agentName}`;
    if (teamName) return `Equipe: ${teamName}`;
    if (agentName) return `Atendente: ${agentName}`;
    return props.data?.transfer_message || 'Transferir para atendimento humano';
  }
  if (props.data?.text) return props.data.text;
  if (props.data?.body) return props.data.body;
  if (props.data?.stage_name) return `Estágio: ${props.data.stage_name}`;
  if (props.data?.operation) return `Operação: ${props.data.operation}`;
  if (props.type === 'start') return 'Gatilho de entrada configurado';
  return 'Clique para configurar este bloco';
});
</script>

<template>
  <div
    class="min-w-[220px] max-w-[280px] bg-n-solid-1 rounded-xl border transition-all duration-200 shadow-md select-none group"
    :class="[
      selected ? 'ring-2 ring-n-brand border-n-brand shadow-lg' : 'border-n-strong hover:border-n-slate-8',
    ]"
  >
    <!-- Handle de Entrada (Target) -->
    <Handle
      v-if="nodeMeta.hasTarget"
      type="target"
      :position="Position.Top"
      class="!size-3 !bg-n-brand !border-2 !border-white dark:!border-n-solid-1 transition-transform group-hover:scale-125"
    />

    <!-- Cabeçalho do Nó -->
    <div
      class="flex items-center justify-between px-3 py-2 rounded-t-xl border-b text-xs font-semibold"
      :class="nodeMeta.color"
    >
      <div class="flex items-center gap-2 truncate">
        <Icon :icon="nodeMeta.icon" class="size-4 shrink-0" />
        <span class="truncate">{{ data?.label || nodeMeta.label }}</span>
      </div>

      <button
        v-if="type !== 'start'"
        type="button"
        class="opacity-0 group-hover:opacity-100 hover:text-rose-500 transition-opacity ml-1 p-0.5"
        title="Remover nó"
        @click.stop="emit('delete', id)"
      >
        <Icon icon="i-lucide-trash" class="size-3.5" />
      </button>
    </div>

    <!-- Conteúdo / Preview do Nó -->
    <div class="p-3 text-xs text-n-slate-11">
      <p class="line-clamp-2 leading-relaxed">
        {{ nodePreview }}
      </p>

      <!-- Opções Interativas com Saídas Dedicadas (Handles) -->
      <div
        v-if="data?.buttons?.length || data?.items?.length"
        class="flex flex-col gap-1.5 mt-2.5 pt-2 border-t border-n-strong/60"
      >
        <div
          v-for="item in (data.buttons || data.items || [])"
          :key="item.id"
          class="relative flex items-center justify-between px-2.5 py-1.5 rounded-lg bg-n-alpha-2 text-n-slate-12 border border-n-strong/40 text-[11px] group/item transition-colors hover:bg-n-alpha-3"
        >
          <span class="truncate font-medium pr-3">{{ item.title }}</span>
          <Handle
            type="source"
            :id="item.id"
            :position="Position.Right"
            class="!size-2.5 !bg-amber-500 !border-2 !border-white dark:!border-n-solid-1 transition-transform group-hover/item:scale-125 !right-[-6px]"
            :title="`Conectar saída: ${item.title}`"
          />
        </div>
      </div>
    </div>

    <!-- Handle de Saída (Source) -->
    <Handle
      v-if="nodeMeta.hasSource"
      type="source"
      :position="Position.Bottom"
      class="!size-3 !bg-n-brand !border-2 !border-white dark:!border-n-solid-1 transition-transform group-hover:scale-125"
    />
  </div>
</template>
