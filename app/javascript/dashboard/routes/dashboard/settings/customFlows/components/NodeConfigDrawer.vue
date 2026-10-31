<script setup>
import { computed } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineOptions({
  name: 'NodeConfigDrawer',
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

      <!-- Configuração por Tipo: Assistente IA Bedrock -->
      <div v-if="node.type === 'ai_fallback' || node.type === 'ai_agent'" class="flex flex-col gap-3">
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Instrução do Assistente (System Prompt)
          </label>
          <textarea
            :value="nodeData.system_prompt || ''"
            rows="4"
            placeholder="Ex: Você é o assistente virtual da GG2. Responda em tom cordial e tire dúvidas sobre pedidos..."
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('system_prompt', $event.target.value)"
          />
        </div>
      </div>

      <!-- Configuração por Tipo: Transferir para Atendente -->
      <div v-if="node.type === 'human_transfer'" class="flex flex-col gap-3">
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Mensagem de Transferência
          </label>
          <textarea
            :value="nodeData.transfer_message || ''"
            rows="3"
            placeholder="Ex: Um momento, estou transferindo seu contato para nossa equipe comercial..."
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
            @input="updateData('transfer_message', $event.target.value)"
          />
        </div>
      </div>

      <!-- Configuração por Tipo: Mover Estágio no Kanban -->
      <div v-if="node.type === 'kanban_stage_change'" class="flex flex-col gap-3">
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            ID do Estágio (slug) *
          </label>
          <input
            :value="nodeData.stage_id || ''"
            type="text"
            placeholder="Ex: lead_qualificado"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @input="updateData('stage_id', $event.target.value)"
          />
        </div>

        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Nome do Estágio Visual *
          </label>
          <input
            :value="nodeData.stage_name || ''"
            type="text"
            placeholder="Ex: Lead Qualificado"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @input="updateData('stage_name', $event.target.value)"
          />
        </div>
      </div>

      <!-- Configuração por Tipo: Consulta Externa / ERP -->
      <div v-if="node.type === 'async_api'" class="flex flex-col gap-3">
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Operação de Consulta
          </label>
          <select
            :value="nodeData.operation || 'consultar_cpf'"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @change="updateData('operation', $event.target.value)"
          >
            <option value="consultar_cpf">Consulta de CPF / Cadastro</option>
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
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
            @input="updateData('wait_message', $event.target.value)"
          />
        </div>
      </div>

      <!-- Configuração por Tipo: Finalização CSAT -->
      <div v-if="node.type === 'finish'" class="flex flex-col gap-3">
        <div>
          <label class="block text-xs font-medium text-n-slate-11 mb-1">
            Mensagem de Despedida
          </label>
          <textarea
            :value="nodeData.farewell_message || ''"
            rows="3"
            placeholder="Ex: Agradecemos seu contato! Tenha um ótimo dia."
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
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
