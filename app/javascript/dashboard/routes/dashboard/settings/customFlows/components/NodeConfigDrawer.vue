<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CustomFlowsAPI from 'dashboard/api/customFlows';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineOptions({
  name: 'NodeConfigDrawer',
});

const VAR_CONTACT_FIRST_NAME = '{{contact.first_name}}';
const VAR_CONTACT_NAME = '{{contact.name}}';
const VAR_CONTACT_PHONE = '{{contact.phone_number}}';
const VAR_ACCOUNT_NAME = '{{account.name}}';

const DAYS_OF_WEEK = [
  { key: 'monday', label: 'Seg' },
  { key: 'tuesday', label: 'Ter' },
  { key: 'wednesday', label: 'Qua' },
  { key: 'thursday', label: 'Qui' },
  { key: 'friday', label: 'Sex' },
  { key: 'saturday', label: 'Sáb' },
  { key: 'sunday', label: 'Dom' },
];

const store = useStore();
const teamsList = useMapGetter('teams/getTeams');
const agentsList = useMapGetter('agents/getAgents');
const labelsList = useMapGetter('labels/getLabels');
const conversationAttributes = useMapGetter('attributes/getConversationAttributes');

const kanbanFunnels = ref([]);
const isLoadingKanban = ref(false);
const isCreatingClosureAttr = ref(false);

const fetchKanbanOptions = async () => {
  isLoadingKanban.value = true;
  try {
    const res = await CustomFlowsAPI.getKanbanOptions();
    kanbanFunnels.value = res.data?.payload?.funnels || [];
  } catch (e) {
    kanbanFunnels.value = [];
  } finally {
    isLoadingKanban.value = false;
  }
};

const createDefaultClosureAttribute = async () => {
  isCreatingClosureAttr.value = true;
  try {
    await store.dispatch('attributes/create', {
      attribute_display_name: 'Motivo de Encerramento',
      attribute_key: 'motivo_encerramento',
      attribute_model: 'conversation_attribute',
      attribute_display_type: 'text',
      attribute_description: 'Motivo de conclusão registrado no encerramento da conversa',
    });
    updateData('closure_attribute_key', 'motivo_encerramento');
  } catch (err) {
    // ignore
  } finally {
    isCreatingClosureAttr.value = false;
  }
};

onMounted(() => {
  store.dispatch('teams/get');
  store.dispatch('agents/get');
  store.dispatch('labels/get');
  store.dispatch('attributes/get');
  fetchKanbanOptions();
});

const props = defineProps({
  node: {
    type: Object,
    default: null,
  },
  isOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'update']);

const nodeData = computed(() => props.node?.data || {});

const updateData = (key, value) => {
  if (!props.node) return;
  const updatedData = { ...nodeData.value, [key]: value };
  emit('update', { ...props.node, data: updatedData });
};

// --- Gestão de Equipe e Atendentes ---
const handleTeamSelect = e => {
  const teamId = e.target.value ? parseInt(e.target.value, 10) : null;
  const team = teamsList.value?.find(t => t.id === teamId);
  const updatedData = {
    ...nodeData.value,
    team_id: teamId,
    team_name: team?.name || '',
  };
  emit('update', { ...props.node, data: updatedData });
};

const handleAgentSelect = e => {
  const agentId = e.target.value ? parseInt(e.target.value, 10) : null;
  const agent = agentsList.value?.find(a => a.id === agentId);
  const updatedData = {
    ...nodeData.value,
    assigned_agent_id: agentId,
    agent_name: agent?.name || '',
  };
  emit('update', { ...props.node, data: updatedData });
};

// --- Gestão de Horário de Atendimento ---
const isDayActive = dayKey => {
  const days = nodeData.value.working_days || ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
  return days.includes(dayKey);
};

const toggleWorkingDay = dayKey => {
  const currentDays = [...(nodeData.value.working_days || ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'])];
  const idx = currentDays.indexOf(dayKey);
  if (idx > -1) {
    currentDays.splice(idx, 1);
  } else {
    currentDays.push(dayKey);
  }
  updateData('working_days', currentDays);
};

// --- Gestão do Kanban Encadeado ---
const selectedFunnelId = computed(() => {
  if (nodeData.value.funnel_id) return nodeData.value.funnel_id;
  if (nodeData.value.stage_id && kanbanFunnels.value.length) {
    const found = kanbanFunnels.value.find(f => (f.stages || []).some(s => s.id === nodeData.value.stage_id));
    if (found) return found.id;
  }
  return kanbanFunnels.value[0]?.id || '';
});

const selectedFunnel = computed(() => {
  return kanbanFunnels.value.find(f => String(f.id) === String(selectedFunnelId.value));
});

const handleFunnelChange = funnelId => {
  const funnel = kanbanFunnels.value.find(f => String(f.id) === String(funnelId));
  const updatedData = {
    ...nodeData.value,
    funnel_id: funnelId,
    funnel_name: funnel?.name || '',
    stage_id: '',
    stage_name: '',
  };
  emit('update', { ...props.node, data: updatedData });
};

const handleStageSelect = stageId => {
  const stage = selectedFunnel.value?.stages?.find(s => String(s.id) === String(stageId));
  const updatedData = {
    ...nodeData.value,
    stage_id: stageId,
    stage_name: stage?.name || stageId,
    funnel_id: selectedFunnel.value?.id,
    funnel_name: selectedFunnel.value?.name,
  };
  emit('update', { ...props.node, data: updatedData });
};

// --- Gestão de Etiquetas ---
const isLabelSelected = labelTitle => {
  return (nodeData.value.labels || []).includes(labelTitle);
};

const toggleLabel = labelTitle => {
  const current = [...(nodeData.value.labels || [])];
  const idx = current.indexOf(labelTitle);
  if (idx > -1) {
    current.splice(idx, 1);
  } else {
    current.push(labelTitle);
  }
  updateData('labels', current);
};

// --- Gestão de Slot Filling em IA ---
const updateRequiredFields = val => {
  const fields = val
    .split(',')
    .map(s => s.trim().toLowerCase())
    .filter(Boolean);
  updateData('required_fields', fields);
};

const addButton = () => {
  const currentButtons = [...(nodeData.value.buttons || [])];
  if (currentButtons.length >= 3) return;

  currentButtons.push({
    id: `btn_${Date.now()}`,
    title: `Opção ${currentButtons.length + 1}`,
  });
  updateData('buttons', currentButtons);
};

const removeButton = index => {
  const currentButtons = [...(nodeData.value.buttons || [])];
  currentButtons.splice(index, 1);
  updateData('buttons', currentButtons);
};

const updateButtonTitle = (index, title) => {
  const currentButtons = [...(nodeData.value.buttons || [])];
  currentButtons[index] = { ...currentButtons[index], title };
  updateData('buttons', currentButtons);
};

const addItem = () => {
  const currentItems = [...(nodeData.value.items || [])];
  if (currentItems.length >= 10) return;

  currentItems.push({
    id: `item_${Date.now()}`,
    title: `Opção ${currentItems.length + 1}`,
    description: '',
  });
  updateData('items', currentItems);
};

const removeItem = index => {
  const currentItems = [...(nodeData.value.items || [])];
  currentItems.splice(index, 1);
  updateData('items', currentItems);
};

const updateItemField = (index, field, value) => {
  const currentItems = [...(nodeData.value.items || [])];
  currentItems[index] = { ...currentItems[index], [field]: value };
  updateData('items', currentItems);
};

const appendVariable = (field, tag) => {
  const currentValue = nodeData.value[field] || '';
  updateData(field, `${currentValue}${currentValue ? ' ' : ''}${tag}`);
};

const LLM_PROVIDERS = [
  { value: 'bedrock', label: 'AWS Bedrock (Corporativo)' },
  { value: 'openai', label: 'OpenAI (GPT-4o / o1)' },
  { value: 'anthropic', label: 'Anthropic (Claude 3.5)' },
  { value: 'gemini', label: 'Google Gemini (1.5 / 2.0)' },
  { value: 'ollama', label: 'Ollama (Local / Self-hosted)' },
];

const LLM_MODELS_BY_PROVIDER = {
  bedrock: [
    { value: 'amazon.nova-lite-v1:0', label: 'Amazon Nova Lite (Rápido & Econômico)' },
    { value: 'amazon.nova-pro-v1:0', label: 'Amazon Nova Pro (Raciocínio Avançado)' },
    { value: 'anthropic.claude-3-5-haiku-20241022-v1:0', label: 'Claude 3.5 Haiku (Bedrock)' },
    { value: 'anthropic.claude-3-5-sonnet-20241022-v2:0', label: 'Claude 3.5 Sonnet (Bedrock)' },
    { value: 'meta.llama3-3-70b-instruct-v1:0', label: 'Meta Llama 3.3 70B (Bedrock)' },
  ],
  openai: [
    { value: 'gpt-4o-mini', label: 'GPT-4o Mini (Rápido & Econômico)' },
    { value: 'gpt-4o', label: 'GPT-4o Omni (Flagship Multimodal)' },
    { value: 'o1-mini', label: 'o1 Mini (Raciocínio & Lógica)' },
  ],
  anthropic: [
    { value: 'claude-3-5-haiku-latest', label: 'Claude 3.5 Haiku (Ultrarrápido)' },
    { value: 'claude-3-5-sonnet-latest', label: 'Claude 3.5 Sonnet (Inteligência Máxima)' },
  ],
  gemini: [
    { value: 'gemini-1.5-flash', label: 'Gemini 1.5 Flash (Ultrarrápido)' },
    { value: 'gemini-1.5-pro', label: 'Gemini 1.5 Pro (Janela Longa de Contexto)' },
    { value: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash (Next-Gen)' },
  ],
  ollama: [
    { value: 'llama3.2', label: 'Llama 3.2 (Local)' },
    { value: 'mistral', label: 'Mistral 7B (Local)' },
    { value: 'deepseek-r1:8b', label: 'DeepSeek R1 8B (Raciocínio Local)' },
  ],
};

const currentProvider = computed(() => nodeData.value.provider || 'bedrock');

const currentModelList = computed(() => {
  return LLM_MODELS_BY_PROVIDER[currentProvider.value] || LLM_MODELS_BY_PROVIDER.bedrock;
});

const onProviderChange = provider => {
  const models = LLM_MODELS_BY_PROVIDER[provider] || [];
  const defaultModel = models[0]?.value || 'amazon.nova-lite-v1:0';
  const updatedData = {
    ...nodeData.value,
    provider,
    model: defaultModel,
  };
  emit('update', { ...props.node, data: updatedData });
};
</script>

<template>
  <div
    v-if="isOpen && node"
    class="absolute top-0 right-0 bottom-0 w-96 bg-n-solid-1 border-l border-n-strong shadow-2xl z-30 flex flex-col transition-all duration-300"
  >
    <!-- Header da Gaveta -->
    <div class="flex items-center justify-between px-5 py-3.5 border-b border-n-strong bg-n-solid-2 shrink-0">
      <div class="flex items-center gap-2">
        <Icon icon="i-lucide-sliders" class="size-4 text-n-brand" />
        <h3 class="text-sm font-semibold text-n-slate-12">
          Configurar Bloco
        </h3>
      </div>

      <button
        type="button"
        class="text-n-slate-9 hover:text-n-slate-12 p-1 rounded-md"
        @click="emit('close')"
      >
        <Icon icon="i-lucide-x" class="size-4" />
      </button>
    </div>

    <!-- Conteúdo com Scroll -->
    <div class="flex-1 overflow-y-auto p-5 flex flex-col gap-4">
      <!-- Rótulo do Nó -->
      <div>
        <label class="block text-xs font-medium text-n-slate-11 mb-1">
          Identificação do Bloco
        </label>
        <input
          :value="nodeData.label || ''"
          type="text"
          placeholder="Ex: Menu Principal"
          class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
          @input="updateData('label', $event.target.value)"
        />
      </div>

      <!-- Status da Etapa / Conversa -->
      <div v-if="node.type !== 'start'">
        <label class="block text-xs font-medium text-n-slate-11 mb-1">
          Status da Conversa nesta Etapa
        </label>
        <input
          :value="nodeData.step_status_value || nodeData.status_value || ''"
          type="text"
          placeholder="Ex: identificacao, cotacao_frete, pix_gerado"
          class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand font-mono"
          @input="updateData('step_status_value', $event.target.value)"
        />
        <p class="text-[11px] text-n-slate-10 mt-1">
          Atribui este status ao campo personalizado da conversa e calcula o tempo de permanência nesta etapa.
        </p>
      </div>

      <!-- Configuração por Tipo: Mensagem -->
      <div v-if="node.type === 'message' || node.type === 'start'">
        <label class="block text-xs font-medium text-n-slate-11 mb-1">
          Texto da Mensagem *
        </label>
        <textarea
          :value="nodeData.text || ''"
          rows="4"
          placeholder="Digite a mensagem que o cliente receberá no WhatsApp..."
          class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
          @input="updateData('text', $event.target.value)"
        />
        <div class="flex items-center gap-1.5 mt-1.5 flex-wrap">
          <span class="text-[10px] text-n-slate-10">Inserir:</span>
          <button
            type="button"
            class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-2 py-0.5 rounded font-mono transition-colors"
            @click="appendVariable('text', VAR_CONTACT_FIRST_NAME)"
          >
            {{ VAR_CONTACT_FIRST_NAME }}
          </button>
          <button
            type="button"
            class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-2 py-0.5 rounded font-mono transition-colors"
            @click="appendVariable('text', VAR_CONTACT_NAME)"
          >
            {{ VAR_CONTACT_NAME }}
          </button>
        </div>
      </div>

      <!-- Configuração por Tipo: Pergunta com Botões -->
      <div v-if="node.type === 'interactive_buttons'" class="flex flex-col gap-3">
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Pergunta / Cabeçalho *
          </label>
          <textarea
            :value="nodeData.body || ''"
            rows="3"
            placeholder="Ex: Como podemos te ajudar hoje?"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('body', $event.target.value)"
          />
          <div class="flex items-center gap-1.5 mt-1.5 flex-wrap">
            <span class="text-[10px] text-n-slate-10">Inserir:</span>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-2 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('body', VAR_CONTACT_FIRST_NAME)"
            >
              {{ VAR_CONTACT_FIRST_NAME }}
            </button>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-2 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('body', VAR_CONTACT_NAME)"
            >
              {{ VAR_CONTACT_NAME }}
            </button>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between mb-2">
            <label class="text-xs font-medium text-n-slate-11">
              Botões de Resposta Rápida (máx. 3)
            </label>
            <button
              v-if="(nodeData.buttons?.length || 0) < 3"
              type="button"
              class="text-xs text-n-brand hover:underline font-medium"
              @click="addButton"
            >
              + Adicionar
            </button>
          </div>

          <div class="flex flex-col gap-2">
            <div
              v-for="(btn, index) in nodeData.buttons || []"
              :key="btn.id"
              class="flex items-center gap-2"
            >
              <input
                :value="btn.title"
                type="text"
                placeholder="Texto do botão (máx. 20 caracteres)"
                maxlength="20"
                class="flex-1 px-3 py-1.5 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
                @input="updateButtonTitle(index, $event.target.value)"
              />
              <button
                type="button"
                class="text-n-slate-9 hover:text-rose-500 p-1"
                @click="removeButton(index)"
              >
                <Icon icon="i-lucide-trash-2" class="size-3.5" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Configuração por Tipo: Lista Interativa WhatsApp -->
      <div v-if="node.type === 'interactive_list'" class="flex flex-col gap-3">
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Pergunta / Cabeçalho da Lista *
          </label>
          <textarea
            :value="nodeData.body || ''"
            rows="3"
            placeholder="Ex: Por favor, escolha como posso te ajudar hoje:"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('body', $event.target.value)"
          />
          <div class="flex items-center gap-1.5 mt-1.5 flex-wrap">
            <span class="text-[10px] text-n-slate-10">Inserir:</span>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-2 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('body', VAR_CONTACT_FIRST_NAME)"
            >
              {{ VAR_CONTACT_FIRST_NAME }}
            </button>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-2 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('body', VAR_CONTACT_NAME)"
            >
              {{ VAR_CONTACT_NAME }}
            </button>
          </div>
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Texto do Botão de Abertura (no chat)
          </label>
          <input
            :value="nodeData.button_text || 'Escolha uma opção'"
            type="text"
            placeholder="Ex: Escolha uma opção"
            maxlength="20"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @input="updateData('button_text', $event.target.value)"
          />
        </div>

        <div>
          <div class="flex items-center justify-between mb-2">
            <label class="text-xs font-medium text-n-slate-11">
              Opções do Menu (máx. 10)
            </label>
            <button
              v-if="(nodeData.items?.length || 0) < 10"
              type="button"
              class="text-xs text-n-brand hover:underline font-medium"
              @click="addItem"
            >
              + Adicionar Opção
            </button>
          </div>

          <div class="flex flex-col gap-3">
            <div
              v-for="(item, index) in nodeData.items || []"
              :key="item.id"
              class="p-2.5 rounded-lg border border-n-strong bg-n-solid-2 flex flex-col gap-2 relative group"
            >
              <div class="flex items-center gap-2">
                <input
                  :value="item.title"
                  type="text"
                  placeholder="Título (Ex: Compras e Orçamentos)"
                  maxlength="24"
                  class="flex-1 px-2.5 py-1 text-xs rounded border border-n-strong bg-n-solid-1 text-n-slate-12 outline-none focus:border-n-brand font-medium"
                  @input="updateItemField(index, 'title', $event.target.value)"
                />
                <button
                  type="button"
                  class="text-n-slate-9 hover:text-rose-500 p-1"
                  title="Remover opção"
                  @click="removeItem(index)"
                >
                  <Icon icon="i-lucide-trash-2" class="size-3.5" />
                </button>
              </div>

              <input
                :value="item.description || ''"
                type="text"
                placeholder="Descrição (Ex: Fazer compras, cotações e orçamentos)"
                maxlength="72"
                class="w-full px-2.5 py-1 text-[11px] rounded border border-n-strong bg-n-solid-1 text-n-slate-11 outline-none focus:border-n-brand"
                @input="updateItemField(index, 'description', $event.target.value)"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Configuração por Tipo: Horário de Atendimento -->
      <div v-if="node.type === 'business_hours'" class="flex flex-col gap-3">
        <div class="p-3 rounded-lg bg-blue-500/10 border border-blue-500/20 text-xs text-blue-600 dark:text-blue-400 leading-relaxed">
          Este bloco verifica o expediente comercial da equipe configurada. Se dentro do horário, avança normalmente. Se fora, envia a mensagem abaixo.
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Mensagem de Fora do Expediente
          </label>
          <textarea
            :value="nodeData.offline_message || ''"
            rows="3"
            placeholder="Ex: Nosso horário de atendimento é de seg a sex, das 8h às 18h..."
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('offline_message', $event.target.value)"
          />
        </div>
      </div>

      <!-- Configuração por Tipo: Assistente IA Generativa (Multi-LLM) -->
      <div v-if="node.type === 'ai_fallback' || node.type === 'ai_agent'" class="flex flex-col gap-3">
        <!-- Provedor LLM -->
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Provedor de Inteligência Artificial *
          </label>
          <select
            :value="currentProvider"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @change="onProviderChange($event.target.value)"
          >
            <option
              v-for="prov in LLM_PROVIDERS"
              :key="prov.value"
              :value="prov.value"
            >
              {{ prov.label }}
            </option>
          </select>
        </div>

        <!-- Modelo LLM -->
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Modelo de LLM *
          </label>
          <select
            :value="nodeData.model || currentModelList[0]?.value"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @change="updateData('model', $event.target.value)"
          >
            <option
              v-for="mdl in currentModelList"
              :key="mdl.value"
              :value="mdl.value"
            >
              {{ mdl.label }}
            </option>
            <option value="custom">Outro modelo (especificar)...</option>
          </select>
        </div>

        <!-- Modelo Customizado (se selecionado custom ou se não estiver na lista padrão) -->
        <div v-if="nodeData.model === 'custom' || (!currentModelList.some(m => m.value === nodeData.model) && nodeData.custom_model)">
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Identificador do Modelo Customizado *
          </label>
          <input
            :value="nodeData.custom_model || ''"
            type="text"
            placeholder="Ex: meta.llama3-8b-instruct-v1:0 ou gpt-4-turbo"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @input="updateData('custom_model', $event.target.value)"
          />
        </div>

        <!-- Parâmetros de Inferência: Temperatura e Tokens -->
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="block text-xs font-medium text-n-slate-11 mb-1">
              Temperatura
            </label>
            <select
              :value="nodeData.temperature !== undefined ? String(nodeData.temperature) : '0.3'"
              class="w-full px-2.5 py-1.5 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
              @change="updateData('temperature', parseFloat($event.target.value))"
            >
              <option value="0.1">0.1 (Mais Precisa)</option>
              <option value="0.3">0.3 (Equilibrada)</option>
              <option value="0.7">0.7 (Mais Criativa)</option>
            </select>
          </div>

          <div>
            <label class="block text-xs font-medium text-n-slate-11 mb-1">
              Tokens Máximos
            </label>
            <select
              :value="nodeData.max_tokens ? String(nodeData.max_tokens) : '300'"
              class="w-full px-2.5 py-1.5 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
              @change="updateData('max_tokens', parseInt($event.target.value, 10))"
            >
              <option value="150">150 (~100 pal.)</option>
              <option value="300">300 (~200 pal.)</option>
              <option value="600">600 (~400 pal.)</option>
            </select>
          </div>
        </div>

        <!-- System Prompt com Inserção de Variáveis -->
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Instrução do Assistente (System Prompt) *
          </label>
          <textarea
            :value="nodeData.system_prompt || ''"
            rows="4"
            placeholder="Ex: Você é o assistente virtual da GG2. Responda em tom cordial e tire dúvidas sobre pedidos..."
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('system_prompt', $event.target.value)"
          />
          <div class="flex items-center gap-1.5 mt-1.5 flex-wrap">
            <span class="text-[10px] text-n-slate-10">Inserir:</span>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-2 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('system_prompt', VAR_CONTACT_FIRST_NAME)"
            >
              {{ VAR_CONTACT_FIRST_NAME }}
            </button>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-2 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('system_prompt', VAR_CONTACT_NAME)"
            >
              {{ VAR_CONTACT_NAME }}
            </button>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-2 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('system_prompt', VAR_ACCOUNT_NAME)"
            >
              {{ VAR_ACCOUNT_NAME }}
            </button>
          </div>
        </div>

        <!-- Mensagem de Fallback / Contingência -->
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Mensagem de Contingência (Fallback)
          </label>
          <textarea
            :value="nodeData.fallback_message || ''"
            rows="2"
            placeholder="Ex: Compreendo sua dúvida! Vou transferir sua conversa para um atendente humano..."
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('fallback_message', $event.target.value)"
          />
        </div>

        <!-- Coleta de Dados Estruturados (Slot Filling Multi-turn) -->
        <div class="p-3 rounded-xl border border-purple-500/30 bg-purple-500/5 flex flex-col gap-3">
          <div class="flex items-center justify-between">
            <div>
              <span class="text-xs font-semibold text-n-slate-12 flex items-center gap-1.5">
                <Icon icon="i-lucide-brain" class="size-3.5 text-purple-600 dark:text-purple-400" />
                Coleta Inteligente (Slot Filling)
              </span>
              <p class="text-[11px] text-n-slate-10 mt-0.5">
                Mantém o cliente nesta etapa até coletar os campos necessários via IA.
              </p>
            </div>
            <label class="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                :checked="Boolean(nodeData.extract_slots)"
                class="sr-only peer"
                @change="updateData('extract_slots', $event.target.checked)"
              />
              <div class="w-8 h-4 bg-n-slate-6 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-3 after:w-3 after:transition-all peer-checked:bg-purple-600"></div>
            </label>
          </div>

          <div v-if="nodeData.extract_slots" class="flex flex-col gap-3 pt-2 border-t border-purple-500/20">
            <div>
              <label class="block text-[11px] font-medium text-n-slate-11 mb-1">
                Campos Obrigatórios (separados por vírgula) *
              </label>
              <input
                :value="(nodeData.required_fields || []).join(', ')"
                type="text"
                placeholder="Ex: cpf, cep"
                class="w-full px-2.5 py-1.5 text-xs rounded-lg border border-n-strong bg-n-solid-1 text-n-slate-12 outline-none focus:border-n-brand font-mono"
                @input="updateRequiredFields($event.target.value)"
              />
            </div>

            <div>
              <label class="block text-[11px] font-medium text-n-slate-11 mb-1">
                Mensagem ao Concluir Coleta com Sucesso
              </label>
              <input
                :value="nodeData.completed_message || ''"
                type="text"
                placeholder="Ex: Perfeito! Localizamos seus dados. Consultando opções..."
                class="w-full px-2.5 py-1.5 text-xs rounded-lg border border-n-strong bg-n-solid-1 text-n-slate-12 outline-none focus:border-n-brand"
                @input="updateData('completed_message', $event.target.value)"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Configuração por Tipo: Transferir para Atendente -->
      <div v-if="node.type === 'human_transfer'" class="flex flex-col gap-4">
        <!-- Seleção de Equipe (Time) -->
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
            Equipe / Fila de Atendimento
          </label>
          <div class="relative">
            <select
              :value="nodeData.team_id || ''"
              class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand appearance-none pr-8 cursor-pointer font-medium"
              @change="handleTeamSelect"
            >
              <option value="">Nenhuma equipe específica (Fila Geral)</option>
              <option
                v-for="team in teamsList"
                :key="team.id"
                :value="team.id"
              >
                👥 {{ team.name }}
              </option>
            </select>
            <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-n-slate-9">
              <Icon icon="i-lucide-chevron-down" class="size-4" />
            </div>
          </div>
          <p class="text-[11px] text-n-slate-10 mt-1">
            A conversa será transferida para a fila dos atendentes deste time.
          </p>
        </div>

        <!-- Seleção de Atendente Responsável -->
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1.5">
            Atendente Responsável (Opcional)
          </label>
          <div class="relative">
            <select
              :value="nodeData.assigned_agent_id || nodeData.agent_id || ''"
              class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand appearance-none pr-8 cursor-pointer font-medium"
              @change="handleAgentSelect"
            >
              <option value="">Distribuição automática (Round-Robin da equipe)</option>
              <option
                v-for="agent in agentsList"
                :key="agent.id"
                :value="agent.id"
              >
                👤 {{ agent.name }} ({{ agent.email }})
              </option>
            </select>
            <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-n-slate-9">
              <Icon icon="i-lucide-chevron-down" class="size-4" />
            </div>
          </div>
          <p class="text-[11px] text-n-slate-10 mt-1">
            Se selecionado, atribui a conversa diretamente a este atendente humano.
          </p>
        </div>

        <!-- Horário de Atendimento & Expediente -->
        <div class="p-3 rounded-xl border border-n-strong bg-n-solid-2 flex flex-col gap-3">
          <div class="flex items-center justify-between">
            <div>
              <span class="text-xs font-semibold text-n-slate-12 flex items-center gap-1.5">
                <Icon icon="i-lucide-clock" class="size-3.5 text-n-brand" />
                Controle de Horário de Atendimento
              </span>
              <p class="text-[11px] text-n-slate-10 mt-0.5">
                Valida se o cliente está entrando em contato dentro do expediente.
              </p>
            </div>
            <label class="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                :checked="nodeData.enable_business_hours !== false"
                class="sr-only peer"
                @change="updateData('enable_business_hours', $event.target.checked)"
              />
              <div class="w-8 h-4 bg-n-slate-6 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-3 after:w-3 after:transition-all peer-checked:bg-n-brand"></div>
            </label>
          </div>

          <div v-if="nodeData.enable_business_hours !== false" class="flex flex-col gap-3 pt-2 border-t border-n-strong/60">
            <!-- Dias da Semana -->
            <div>
              <label class="block text-[11px] font-medium text-n-slate-11 mb-1.5">
                Dias de Atendimento
              </label>
              <div class="flex items-center gap-1.5 flex-wrap">
                <button
                  v-for="day in DAYS_OF_WEEK"
                  :key="day.key"
                  type="button"
                  class="px-2.5 py-1 text-xs rounded-lg font-medium transition-all"
                  :class="[
                    isDayActive(day.key)
                      ? 'bg-n-brand text-white shadow-sm'
                      : 'bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3 border border-n-strong'
                  ]"
                  @click="toggleWorkingDay(day.key)"
                >
                  {{ day.label }}
                </button>
              </div>
            </div>

            <!-- Intervalo de Horário -->
            <div class="grid grid-cols-2 gap-2.5">
              <div>
                <label class="block text-[11px] font-medium text-n-slate-11 mb-1">
                  Horário de Início
                </label>
                <input
                  :value="nodeData.open_hour || '08:00'"
                  type="time"
                  class="w-full px-2.5 py-1.5 text-xs rounded-lg border border-n-strong bg-n-solid-1 text-n-slate-12 outline-none focus:border-n-brand font-medium"
                  @change="updateData('open_hour', $event.target.value)"
                />
              </div>
              <div>
                <label class="block text-[11px] font-medium text-n-slate-11 mb-1">
                  Horário de Término
                </label>
                <input
                  :value="nodeData.close_hour || '18:00'"
                  type="time"
                  class="w-full px-2.5 py-1.5 text-xs rounded-lg border border-n-strong bg-n-solid-1 text-n-slate-12 outline-none focus:border-n-brand font-medium"
                  @change="updateData('close_hour', $event.target.value)"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Mensagem Dentro do Expediente -->
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1 flex items-center gap-1.5">
            <span class="size-2 rounded-full bg-emerald-500"></span>
            Mensagem DENTRO do Expediente
          </label>
          <textarea
            :value="nodeData.transfer_message || ''"
            rows="2"
            placeholder="Ex: Um momento, {{contact.first_name}}, estou transferindo seu contato para nossa equipe..."
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('transfer_message', $event.target.value)"
          />
          <div class="flex items-center gap-1 mt-1 flex-wrap">
            <span class="text-[10px] text-n-slate-10">Inserir:</span>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-1.5 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('transfer_message', VAR_CONTACT_FIRST_NAME)"
            >
              {{ VAR_CONTACT_FIRST_NAME }}
            </button>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-1.5 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('transfer_message', VAR_CONTACT_NAME)"
            >
              {{ VAR_CONTACT_NAME }}
            </button>
          </div>
        </div>

        <!-- Mensagem Fora do Expediente -->
        <div v-if="nodeData.enable_business_hours !== false">
          <label class="block text-xs font-medium text-n-slate-11 mb-1 flex items-center gap-1.5">
            <span class="size-2 rounded-full bg-amber-500"></span>
            Mensagem FORA do Expediente (Offline)
          </label>
          <textarea
            :value="nodeData.out_of_office_message || ''"
            rows="2"
            placeholder="Ex: Olá, {{contact.first_name}}! Nosso atendimento funciona de Seg a Sex, das 08h às 18h. Já registramos sua mensagem e responderemos assim que retornarmos!"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('out_of_office_message', $event.target.value)"
          />
          <div class="flex items-center gap-1 mt-1 flex-wrap">
            <span class="text-[10px] text-n-slate-10">Inserir:</span>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-1.5 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('out_of_office_message', VAR_CONTACT_FIRST_NAME)"
            >
              {{ VAR_CONTACT_FIRST_NAME }}
            </button>
            <button
              type="button"
              class="text-[10px] bg-n-alpha-2 hover:bg-n-brand/10 hover:text-n-brand text-n-slate-11 px-1.5 py-0.5 rounded font-mono transition-colors"
              @click="appendVariable('out_of_office_message', VAR_CONTACT_NAME)"
            >
              {{ VAR_CONTACT_NAME }}
            </button>
          </div>
        </div>
      </div>

      <!-- Configuração por Tipo: Mover Estágio no Kanban -->
      <div v-if="node.type === 'kanban_stage_change'" class="flex flex-col gap-3">
        <!-- Empty State se não houver funis cadastrados -->
        <div
          v-if="!isLoadingKanban && kanbanFunnels.length === 0"
          class="p-4 rounded-xl border border-amber-500/30 bg-amber-500/10 text-amber-800 dark:text-amber-300 flex flex-col gap-2"
        >
          <div class="flex items-center gap-2 font-semibold text-xs">
            <Icon icon="i-lucide-alert-triangle" class="size-4 shrink-0 text-amber-600 dark:text-amber-400" />
            <span>Nenhum Funil Encontrado</span>
          </div>
          <p class="text-[11px] leading-relaxed">
            Para mover um contato no Kanban, é necessário criar um Funil e seus respectivos Estágios primeiro.
          </p>
          <div class="pt-1">
            <span class="inline-block text-[11px] font-medium text-amber-700 dark:text-amber-300 underline">
              👉 Crie um funil no menu Kanban antes de selecionar este bloco.
            </span>
          </div>
        </div>

        <!-- Seletor Encadeado de Funil e Estágio -->
        <div v-else class="flex flex-col gap-3">
          <div>
            <label class="block text-xs font-medium text-n-slate-11 mb-1">
              Funil / Pipeline *
            </label>
            <select
              :value="selectedFunnelId"
              class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
              @change="handleFunnelChange($event.target.value)"
            >
              <option value="">-- Selecione o Funil --</option>
              <option
                v-for="funnel in kanbanFunnels"
                :key="funnel.id"
                :value="funnel.id"
              >
                📊 {{ funnel.name }} ({{ funnel.stages?.length || 0 }} etapas)
              </option>
            </select>
          </div>

          <div v-if="selectedFunnel">
            <div
              v-if="!selectedFunnel.stages || selectedFunnel.stages.length === 0"
              class="p-3 rounded-lg border border-amber-500/30 bg-amber-500/10 text-xs text-amber-800 dark:text-amber-300"
            >
              ⚠️ Este funil não possui etapas cadastradas. Crie um novo step no kanban para poder selecioná-lo aqui.
            </div>

            <div v-else>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">
                Estágio de Destino (Step) *
              </label>
              <select
                :value="nodeData.stage_id || ''"
                class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
                @change="handleStageSelect($event.target.value)"
              >
                <option value="">-- Selecione a Etapa do Funil --</option>
                <option
                  v-for="stage in selectedFunnel.stages"
                  :key="stage.id"
                  :value="stage.id"
                >
                  🏷️ {{ stage.name }}
                </option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Configuração por Tipo: Gerenciar Etiquetas -->
      <div v-if="node.type === 'manage_labels'" class="flex flex-col gap-3">
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Alvo da Ação *
          </label>
          <select
            :value="nodeData.target || 'conversation'"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @change="updateData('target', $event.target.value)"
          >
            <option value="conversation">Na Conversa</option>
            <option value="contact">No Contato</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Ação *
          </label>
          <select
            :value="nodeData.action || 'add'"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @change="updateData('action', $event.target.value)"
          >
            <option value="add">Adicionar Etiqueta(s)</option>
            <option value="remove">Remover Etiqueta(s)</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Selecionar Etiquetas da Conta
          </label>
          <div class="flex items-center gap-1.5 flex-wrap max-h-40 overflow-y-auto p-2.5 rounded-lg border border-n-strong bg-n-solid-2">
            <span v-if="!labelsList || labelsList.length === 0" class="text-xs text-n-slate-10">
              Nenhuma etiqueta cadastrada na conta.
            </span>
            <button
              v-for="label in labelsList || []"
              :key="label.id"
              type="button"
              class="px-2.5 py-1 text-xs rounded-lg border transition-all flex items-center gap-1.5"
              :class="isLabelSelected(label.title) ? 'bg-n-brand text-white border-n-brand shadow-sm' : 'bg-n-alpha-2 text-n-slate-11 border-n-strong hover:bg-n-alpha-3'"
              @click="toggleLabel(label.title)"
            >
              <span class="size-2 rounded-full" :style="{ backgroundColor: label.color || '#3b82f6' }"></span>
              {{ label.title }}
            </button>
          </div>
        </div>
      </div>

      <!-- Configuração por Tipo: Decisão Condicional (Se/Senão) -->
      <div v-if="node.type === 'condition_router'" class="flex flex-col gap-3">
        <div class="p-3 rounded-xl border border-sky-500/30 bg-sky-500/5 text-xs text-sky-800 dark:text-sky-300 flex flex-col gap-1">
          <span class="font-semibold flex items-center gap-1.5">
            <Icon icon="i-lucide-git-branch" class="size-4 text-sky-600 dark:text-sky-400" />
            Decisão Condicional (Se / Senão)
          </span>
          <p class="text-[11px] leading-relaxed">
            Se a condição for atendida, o fluxo avança pela saída <strong>✓ Sim (Verdadeiro)</strong>. Caso contrário, avança pela saída <strong>✗ Não (Falso)</strong>.
          </p>
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Variável de Contexto *
          </label>
          <input
            :value="nodeData.variable || ''"
            type="text"
            placeholder="Ex: customer_found ou context.amount"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand font-mono"
            @input="updateData('variable', $event.target.value)"
          />
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Operador *
          </label>
          <select
            :value="nodeData.operator || 'equals'"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @change="updateData('operator', $event.target.value)"
          >
            <option value="equals">Igual a (==)</option>
            <option value="not_equals">Diferente de (!=)</option>
            <option value="present">Está Preenchido (Presente)</option>
            <option value="blank">Está Vazio (Ausente)</option>
            <option value="contains">Contém Texto</option>
          </select>
        </div>

        <div v-if="nodeData.operator !== 'present' && nodeData.operator !== 'blank'">
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Valor Esperado *
          </label>
          <input
            :value="nodeData.expected_value || ''"
            type="text"
            placeholder="Ex: true, ouro, 100"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand font-mono"
            @input="updateData('expected_value', $event.target.value)"
          />
        </div>
      </div>

      <!-- Configuração por Tipo: Tratamento de Falhas (Try/Catch) -->
      <div v-if="node.type === 'try_catch'" class="flex flex-col gap-3">
        <div class="p-3 rounded-xl border border-orange-500/30 bg-orange-500/5 text-xs text-orange-800 dark:text-orange-300 flex flex-col gap-1">
          <span class="font-semibold flex items-center gap-1.5">
            <Icon icon="i-lucide-shield-alert" class="size-4 text-orange-600 dark:text-orange-400" />
            Tratamento de Falhas & Retentativas
          </span>
          <p class="text-[11px] leading-relaxed">
            Encaminha pela saída <strong>✓ Executar (Try)</strong> até o limite de tentativas. Se o limite for excedido, avança pela saída <strong>✗ Falha / Limite (Catch)</strong>.
          </p>
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Número Máximo de Tentativas *
          </label>
          <input
            :value="nodeData.max_retries || 3"
            type="number"
            min="1"
            max="10"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand font-mono"
            @input="updateData('max_retries', parseInt($event.target.value, 10))"
          />
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Mensagem de Retentativa para o Cliente
          </label>
          <textarea
            :value="nodeData.retry_message || ''"
            rows="2"
            placeholder="Ex: Tivemos uma oscilação temporária de conexão. Tentando novamente..."
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('retry_message', $event.target.value)"
          />
        </div>
      </div>

      <!-- Configuração por Tipo: Consulta Externa / Processamento Assíncrono -->
      <div v-if="node.type === 'async_api'" class="flex flex-col gap-3">
        <div class="p-3 rounded-xl border border-cyan-500/30 bg-cyan-500/5 text-xs text-cyan-800 dark:text-cyan-300 flex flex-col gap-1">
          <span class="font-semibold flex items-center gap-1.5">
            <span class="size-2 rounded-full bg-cyan-500 animate-pulse"></span>
            Processamento em Background (Fila :flows_processing)
          </span>
          <p class="text-[11px] leading-relaxed">
            Executa em background sem travar os atendentes. Possui saídas dedicadas para <strong>✓ Sucesso</strong> e <strong>✗ Erro</strong>.
          </p>
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Operação do Sistema / ERP / Magento *
          </label>
          <select
            :value="nodeData.operation || 'consultar_cpf'"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @change="updateData('operation', $event.target.value)"
          >
            <option value="consultar_cpf">Consulta de CPF / Cadastro Simples</option>
            <option value="magento_customer_lookup">Magento: Consultar Cliente & Limite</option>
            <option value="magento_search_products">Magento: Catálogo de Produtos</option>
            <option value="magento_create_quote">Magento: Criar Cotação & Frete</option>
            <option value="magento_place_order">Magento: Fechar Pedido & Gerar Pix</option>
            <option value="pedidos_recentes">Histórico de Pedidos</option>
            <option value="saldo_revendedora">Saldo e Limite de Crédito</option>
            <option value="rastreio_envio">Rastreamento de Encomenda</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Mensagem Imediata de Aguardo
          </label>
          <input
            :value="nodeData.wait_message || '⏳ Aguarde um instante enquanto consultamos nossos sistemas...'"
            type="text"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @input="updateData('wait_message', $event.target.value)"
          />
        </div>
      </div>

      <!-- Configuração por Tipo: Finalização com Motivo -->
      <div v-if="node.type === 'finish'" class="flex flex-col gap-3">
        <div>
          <div class="flex items-center justify-between mb-1">
            <label class="block text-xs font-medium text-n-slate-11">
              Campo de Motivo de Encerramento (Custom Attribute)
            </label>
            <button
              v-if="!conversationAttributes || !conversationAttributes.some(a => a.attributeKey === 'motivo_encerramento')"
              type="button"
              class="text-[11px] text-n-brand hover:underline font-medium"
              :disabled="isCreatingClosureAttr"
              @click="createDefaultClosureAttribute"
            >
              + Criar "motivo_encerramento"
            </button>
          </div>

          <select
            v-if="conversationAttributes && conversationAttributes.length > 0"
            :value="nodeData.closure_attribute_key || 'motivo_encerramento'"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @change="updateData('closure_attribute_key', $event.target.value)"
          >
            <option value="">-- Não gravar motivo em atributo --</option>
            <option
              v-for="attr in conversationAttributes"
              :key="attr.id"
              :value="attr.attributeKey"
            >
              🏷️ {{ attr.attributeDisplayName }} ({{ attr.attributeKey }})
            </option>
          </select>

          <div
            v-else
            class="p-2.5 rounded-lg border border-amber-500/20 bg-amber-500/5 text-xs text-amber-800 dark:text-amber-300 flex items-center justify-between gap-2"
          >
            <span class="text-[11px]">Nenhum atributo de conversa encontrado.</span>
            <Button
              label="Criar Atributo"
              size="xs"
              variant="faded"
              :loading="isCreatingClosureAttr"
              @click="createDefaultClosureAttribute"
            />
          </div>
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Motivo do Encerramento *
          </label>
          <input
            :value="nodeData.closure_reason || ''"
            type="text"
            placeholder="Ex: Venda Concluída, Dúvida Sanada, Sem Interesse"
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @input="updateData('closure_reason', $event.target.value)"
          />
          <p class="text-[11px] text-n-slate-10 mt-1">
            Gravado no atributo de conversa no momento do encerramento para relatórios e automações.
          </p>
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Mensagem de Despedida
          </label>
          <textarea
            :value="nodeData.farewell_message || ''"
            rows="3"
            placeholder="Ex: Agradecemos seu contato! Tenha um ótimo dia."
            class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('farewell_message', $event.target.value)"
          />
        </div>
      </div>
    </div>

    <!-- Footer da Gaveta -->
    <div class="p-4 border-t border-n-strong bg-n-solid-2 shrink-0">
      <Button
        label="Concluir Edição"
        variant="solid"
        class="w-full"
        size="sm"
        @click="emit('close')"
      />
    </div>
  </div>
</template>
