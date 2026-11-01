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
        label: 'Mover no Funil / Kanban',
        icon: 'i-lucide-columns-3',
        color: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border-indigo-500/30',
        hasTarget: true,
        hasSource: true,
      };
    case 'manage_labels':
      return {
        label: 'Gerenciar Etiquetas',
        icon: 'i-lucide-tags',
        color: 'bg-violet-500/10 text-violet-600 dark:text-violet-400 border-violet-500/30',
        hasTarget: true,
        hasSource: true,
      };
    case 'condition_router':
      return {
        label: 'Decisão Condicional',
        icon: 'i-lucide-git-branch',
        color: 'bg-sky-500/10 text-sky-600 dark:text-sky-400 border-sky-500/30',
        hasTarget: true,
        hasSource: false,
      };
    case 'try_catch':
      return {
        label: 'Tratamento de Erros (Try/Catch)',
        icon: 'i-lucide-shield-alert',
        color: 'bg-orange-500/10 text-orange-600 dark:text-orange-400 border-orange-500/30',
        hasTarget: true,
        hasSource: false,
      };
    case 'async_api':
      return {
        label: 'Processamento Assíncrono / API',
        icon: 'i-lucide-database',
        color: 'bg-cyan-500/10 text-cyan-600 dark:text-cyan-400 border-cyan-500/30',
        hasTarget: true,
        hasSource: false,
      };
    case 'finish':
      return {
        label: 'Encerrar Conversa',
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
    if (props.data?.extract_slots) {
      const fields = (props.data?.required_fields || []).join(', ') || 'nenhum';
      return `Slot Filling [${fields}]`;
    }
    const prov = props.data?.provider || 'bedrock';
    const mdl = props.data?.model === 'custom' && props.data?.custom_model ? props.data.custom_model : (props.data?.model || 'amazon.nova-lite-v1:0');
    return `IA [${prov}]: ${mdl}`;
  }
  if (props.type === 'human_transfer') {
    const teamName = props.data?.team_name || (props.data?.team_id ? `Equipe #${props.data.team_id}` : null);
    const agentName = props.data?.agent_name || (props.data?.assigned_agent_id ? `Atendente #${props.data.assigned_agent_id}` : null);
    const destination = teamName && agentName ? `${teamName} • ${agentName}` : (teamName || agentName || 'Fila Geral');
    const hasHours = props.data?.enable_business_hours !== false;
    const hours = hasHours ? ` [${props.data?.open_hour || '08:00'}-${props.data?.close_hour || '18:00'}]` : ' [24h]';
    return `Destino: ${destination}${hours}`;
  }
  if (props.type === 'kanban_stage_change') {
    const stage = props.data?.stage_name || props.data?.stage_id || 'Não configurado';
    const funnel = props.data?.funnel_name ? ` (${props.data.funnel_name})` : '';
    return `Mover para: ${stage}${funnel}`;
  }
  if (props.type === 'manage_labels') {
    const act = props.data?.action === 'remove' ? 'Remover' : 'Adicionar';
    const tgt = props.data?.target === 'contact' ? 'Contato' : 'Conversa';
    const lbls = (props.data?.labels || []).join(', ') || 'Nenhuma';
    return `${act} em ${tgt}: [${lbls}]`;
  }
  if (props.type === 'condition_router') {
    return `Se [${props.data?.variable || 'var'}] ${props.data?.operator || 'equals'} '${props.data?.expected_value || ''}'`;
  }
  if (props.type === 'try_catch') {
    return `Retentativas: até ${props.data?.max_retries || 3}x em caso de falha`;
  }
  if (props.type === 'async_api') {
    return `Operação: ${props.data?.operation || 'consultar_cpf'}`;
  }
  if (props.type === 'finish') {
    if (props.data?.closure_reason) {
      return `Motivo: ${props.data.closure_reason}`;
    }
    return props.data?.farewell_message || 'Atendimento encerrado';
  }
  if (props.data?.text) return props.data.text;
  if (props.data?.body) return props.data.body;
  if (props.type === 'start') return 'Gatilho de entrada configurado';
  return 'Clique para configurar este bloco';
});
</script>

<template>
  <div
    class="min-w-[230px] max-w-[290px] bg-n-solid-1 rounded-xl border transition-all duration-200 shadow-md select-none group"
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

    <!-- Indicador Especial de Processamento Assíncrono -->
    <div
      v-if="type === 'async_api'"
      class="px-3 py-1 bg-cyan-500/10 border-b border-cyan-500/20 flex items-center justify-between text-[10px] font-medium text-cyan-600 dark:text-cyan-400"
    >
      <span class="flex items-center gap-1">
        <span class="size-1.5 rounded-full bg-cyan-500 animate-pulse"></span>
        Paralelo (Fila :flows_processing)
      </span>
      <span class="font-mono text-[9px] uppercase tracking-wider">ASYNC</span>
    </div>

    <!-- Conteúdo / Preview do Nó -->
    <div class="p-3 text-xs text-n-slate-11">
      <p class="line-clamp-2 leading-relaxed">
        {{ nodePreview }}
      </p>

      <!-- Badge de Status da Etapa / Conversa -->
      <div
        v-if="data?.step_status_value"
        class="mt-2 inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-n-alpha-2 border border-n-strong/60 text-[10px] text-n-slate-12 font-mono"
        :title="`Status da conversa nesta etapa: ${data.step_status_value}`"
      >
        <span class="size-1.5 rounded-full bg-emerald-500"></span>
        <span class="text-n-slate-10">status:</span>
        <span class="font-semibold">{{ data.step_status_value }}</span>
      </div>

      <!-- Opções Interativas com Saídas Dedicadas (Buttons / List Items) -->
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

      <!-- Saídas Dedicadas: Try / Catch -->
      <div
        v-if="type === 'try_catch'"
        class="flex flex-col gap-1.5 mt-2.5 pt-2 border-t border-n-strong/60"
      >
        <div class="relative flex items-center justify-between px-2.5 py-1.5 rounded-lg bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border border-emerald-500/30 text-[11px] font-medium">
          <span>✓ Executar Tentativa (Try)</span>
          <Handle
            type="source"
            id="try"
            :position="Position.Right"
            class="!size-2.5 !bg-emerald-500 !border-2 !border-white dark:!border-n-solid-1 !right-[-6px]"
            title="Conectar saída de tentativa (Try)"
          />
        </div>
        <div class="relative flex items-center justify-between px-2.5 py-1.5 rounded-lg bg-rose-500/10 text-rose-700 dark:text-rose-400 border border-rose-500/30 text-[11px] font-medium">
          <span>✗ Falha / Máx. Retentativas (Catch)</span>
          <Handle
            type="source"
            id="catch"
            :position="Position.Right"
            class="!size-2.5 !bg-rose-500 !border-2 !border-white dark:!border-n-solid-1 !right-[-6px]"
            title="Conectar saída de contingência (Catch)"
          />
        </div>
      </div>

      <!-- Saídas Dedicadas: Decisão Condicional (True / False) -->
      <div
        v-if="type === 'condition_router'"
        class="flex flex-col gap-1.5 mt-2.5 pt-2 border-t border-n-strong/60"
      >
        <div class="relative flex items-center justify-between px-2.5 py-1.5 rounded-lg bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border border-emerald-500/30 text-[11px] font-medium">
          <span>✓ Sim (Verdadeiro)</span>
          <Handle
            type="source"
            id="true"
            :position="Position.Right"
            class="!size-2.5 !bg-emerald-500 !border-2 !border-white dark:!border-n-solid-1 !right-[-6px]"
            title="Condição atendida (True)"
          />
        </div>
        <div class="relative flex items-center justify-between px-2.5 py-1.5 rounded-lg bg-rose-500/10 text-rose-700 dark:text-rose-400 border border-rose-500/30 text-[11px] font-medium">
          <span>✗ Não (Falso)</span>
          <Handle
            type="source"
            id="false"
            :position="Position.Right"
            class="!size-2.5 !bg-rose-500 !border-2 !border-white dark:!border-n-solid-1 !right-[-6px]"
            title="Condição não atendida (False)"
          />
        </div>
      </div>

      <!-- Saídas Dedicadas: Async API (Success / Error) -->
      <div
        v-if="type === 'async_api'"
        class="flex flex-col gap-1.5 mt-2.5 pt-2 border-t border-n-strong/60"
      >
        <div class="relative flex items-center justify-between px-2.5 py-1.5 rounded-lg bg-cyan-500/10 text-cyan-700 dark:text-cyan-400 border border-cyan-500/30 text-[11px] font-medium">
          <span>✓ Sucesso na Chamada</span>
          <Handle
            type="source"
            id="success"
            :position="Position.Right"
            class="!size-2.5 !bg-cyan-500 !border-2 !border-white dark:!border-n-solid-1 !right-[-6px]"
            title="Conectar saída de sucesso assíncrono"
          />
        </div>
        <div class="relative flex items-center justify-between px-2.5 py-1.5 rounded-lg bg-rose-500/10 text-rose-700 dark:text-rose-400 border border-rose-500/30 text-[11px] font-medium">
          <span>✗ Erro na Resposta / Timeout</span>
          <Handle
            type="source"
            id="error"
            :position="Position.Right"
            class="!size-2.5 !bg-rose-500 !border-2 !border-white dark:!border-n-solid-1 !right-[-6px]"
            title="Conectar saída de erro assíncrono"
          />
        </div>
      </div>
    </div>

    <!-- Handle de Saída Padrão (Source) para nós com saída linear -->
    <Handle
      v-if="nodeMeta.hasSource"
      type="source"
      :position="Position.Bottom"
      class="!size-3 !bg-n-brand !border-2 !border-white dark:!border-n-solid-1 transition-transform group-hover:scale-125"
    />
  </div>
</template>
