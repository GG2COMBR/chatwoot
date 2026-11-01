<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import CustomFlowsAPI from 'dashboard/api/customFlows';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

defineOptions({
  name: 'CustomFlowsIndex',
});

const store = useStore();
const router = useRouter();
const route = useRoute();

const conversationAttributes = useMapGetter('attributes/getConversationAttributes');

const flows = ref([]);
const isLoading = ref(true);
const searchQuery = ref('');
const statusFilter = ref('all');

const showCreateModal = ref(false);
const isSubmitting = ref(false);
const isCreatingAttribute = ref(false);
const newFlowName = ref('');
const newFlowDescription = ref('');
const newFlowTrigger = ref('default');
const newFlowStatusAttrKey = ref('etapa_fluxo');

const fetchFlows = async () => {
  isLoading.value = true;
  try {
    const response = await CustomFlowsAPI.get();
    flows.value = response.data?.payload || [];
  } catch (error) {
    useAlert('Erro ao carregar fluxos do Flowbuilder');
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchFlows();
  store.dispatch('attributes/get');
});

const createDefaultStatusAttribute = async () => {
  isCreatingAttribute.value = true;
  try {
    await store.dispatch('attributes/create', {
      attribute_display_name: 'Etapa do Fluxo',
      attribute_key: 'etapa_fluxo',
      attribute_model: 'conversation_attribute',
      attribute_display_type: 'text',
      attribute_description: 'Status do cliente na etapa atual do Flowbuilder',
    });
    newFlowStatusAttrKey.value = 'etapa_fluxo';
    useAlert('Atributo "etapa_fluxo" criado com sucesso!');
  } catch (err) {
    useAlert('Falha ao criar atributo personalizado');
  } finally {
    isCreatingAttribute.value = false;
  }
};

const filteredFlows = computed(() => {
  return flows.value.filter(flow => {
    const matchesQuery = !searchQuery.value ||
      flow.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      (flow.description && flow.description.toLowerCase().includes(searchQuery.value.toLowerCase()));

    const matchesStatus = statusFilter.value === 'all' || flow.status === statusFilter.value;

    return matchesQuery && matchesStatus;
  });
});

const openCreateModal = () => {
  newFlowName.value = '';
  newFlowDescription.value = '';
  newFlowTrigger.value = 'default';
  newFlowStatusAttrKey.value = 'etapa_fluxo';
  showCreateModal.value = true;
};

const closeCreateModal = () => {
  showCreateModal.value = false;
};

const createFlow = async () => {
  if (!newFlowName.value.trim()) return;

  isSubmitting.value = true;
  try {
    const payload = {
      custom_flow: {
        name: newFlowName.value.trim(),
        description: newFlowDescription.value.trim(),
        trigger_type: newFlowTrigger.value,
        trigger_config: {
          status_custom_attribute_key: newFlowStatusAttrKey.value.trim(),
        },
        nodes: [
          {
            id: 'start',
            type: 'start',
            position: { x: 250, y: 100 },
            data: { label: 'Início da Conversa' },
          },
        ],
        edges: [],
      },
    };

    const response = await CustomFlowsAPI.create(payload);
    const createdFlow = response.data?.payload;
    useAlert('Fluxo criado com sucesso!');
    closeCreateModal();

    if (createdFlow?.id) {
      router.push({
        name: 'custom_flows_edit',
        params: { accountId: route.params.accountId, flowId: createdFlow.id },
      });
    } else {
      fetchFlows();
    }
  } catch (error) {
    useAlert('Falha ao criar o fluxo');
  } finally {
    isSubmitting.value = false;
  }
};

const editFlow = flowId => {
  router.push({
    name: 'custom_flows_edit',
    params: { accountId: route.params.accountId, flowId },
  });
};

const duplicateFlow = async flowId => {
  try {
    await CustomFlowsAPI.duplicate(flowId);
    useAlert('Fluxo duplicado com sucesso!');
    fetchFlows();
  } catch (error) {
    useAlert('Falha ao duplicar fluxo');
  }
};

const deleteFlow = async flow => {
  if (!window.confirm(`Deseja realmente excluir o fluxo "${flow.name}"?`)) return;

  try {
    await CustomFlowsAPI.delete(flow.id);
    useAlert('Fluxo excluído com sucesso');
    fetchFlows();
  } catch (error) {
    useAlert('Erro ao excluir fluxo');
  }
};

const formatTrigger = trigger => {
  if (trigger === 'kanban_stage_entered' || trigger === 'kanban_stage') {
    return 'Gatilho Kanban';
  }
  return 'WhatsApp Padrão';
};

const formatDate = dateString => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  return date.toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        title="Flowbuilder URA"
        description="Crie, edite e acompanhe os fluxos conversacionais inteligentes para WhatsApp e funil de vendas."
      >
        <template #actions>
          <Button
            label="Novo Fluxo"
            icon="i-lucide-plus"
            size="sm"
            @click="openCreateModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-4">
        <!-- Barra de Busca e Filtros -->
        <div class="flex items-center justify-between gap-4 bg-n-alpha-1 dark:bg-n-solid-2 p-3 rounded-lg border border-n-strong">
          <div class="flex items-center gap-2 flex-1 max-w-md">
            <Icon icon="i-lucide-search" class="text-n-slate-10 size-4" />
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar fluxo por nome ou descrição..."
              class="w-full bg-transparent text-sm text-n-slate-12 placeholder-n-slate-9 outline-none"
            />
          </div>

          <div class="flex items-center gap-2 text-xs">
            <span class="text-n-slate-10">Status:</span>
            <button
              class="px-2.5 py-1 rounded transition-colors"
              :class="statusFilter === 'all' ? 'bg-n-brand text-white font-medium' : 'text-n-slate-11 hover:bg-n-alpha-2'"
              @click="statusFilter = 'all'"
            >
              Todos
            </button>
            <button
              class="px-2.5 py-1 rounded transition-colors"
              :class="statusFilter === 'published' ? 'bg-n-brand text-white font-medium' : 'text-n-slate-11 hover:bg-n-alpha-2'"
              @click="statusFilter = 'published'"
            >
              Publicados
            </button>
            <button
              class="px-2.5 py-1 rounded transition-colors"
              :class="statusFilter === 'draft' ? 'bg-n-brand text-white font-medium' : 'text-n-slate-11 hover:bg-n-alpha-2'"
              @click="statusFilter = 'draft'"
            >
              Rascunhos
            </button>
          </div>
        </div>

        <!-- Estado de Carregamento -->
        <div v-if="isLoading" class="flex justify-center items-center py-16">
          <Spinner />
        </div>

        <!-- Lista Vazia -->
        <div
          v-else-if="filteredFlows.length === 0"
          class="flex flex-col items-center justify-center py-16 px-4 text-center border border-dashed border-n-strong rounded-xl bg-n-alpha-1"
        >
          <div class="size-12 rounded-full bg-n-brand/10 text-n-brand flex items-center justify-center mb-3">
            <Icon icon="i-lucide-git-branch" class="size-6" />
          </div>
          <h3 class="text-base font-semibold text-n-slate-12">Nenhum fluxo encontrado</h3>
          <p class="text-xs text-n-slate-10 max-w-sm mt-1 mb-4">
            Crie seu primeiro fluxo de URA conversacional para qualificar clientes e automatizar o atendimento.
          </p>
          <Button
            label="Criar Primeiro Fluxo"
            icon="i-lucide-plus"
            size="sm"
            @click="openCreateModal"
          />
        </div>

        <!-- Tabela / Cards de Fluxos -->
        <div v-else class="grid grid-cols-1 gap-3">
          <div
            v-for="flow in filteredFlows"
            :key="flow.id"
            class="flex items-center justify-between p-4 rounded-xl border border-n-strong bg-n-solid-1 hover:border-n-brand/40 transition-all shadow-sm"
          >
            <div class="flex items-start gap-4">
              <div class="size-10 rounded-lg bg-n-brand/10 text-n-brand flex items-center justify-center shrink-0 mt-0.5">
                <Icon icon="i-lucide-git-branch" class="size-5" />
              </div>

              <div class="flex flex-col">
                <div class="flex items-center gap-2">
                  <h4 class="text-sm font-semibold text-n-slate-12">{{ flow.name }}</h4>
                  <span
                    class="text-[10px] font-medium px-2 py-0.5 rounded-full"
                    :class="flow.status === 'published' ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20' : 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20'"
                  >
                    {{ flow.status === 'published' ? 'Publicado' : 'Rascunho' }}
                  </span>
                  <span class="text-[10px] font-medium px-2 py-0.5 rounded-full bg-n-alpha-2 text-n-slate-11">
                    {{ formatTrigger(flow.trigger_type) }}
                  </span>
                </div>

                <p v-if="flow.description" class="text-xs text-n-slate-10 mt-1 line-clamp-1">
                  {{ flow.description }}
                </p>

                <div class="flex items-center gap-4 text-[11px] text-n-slate-9 mt-2">
                  <span>{{ flow.nodes_count || 0 }} nós no grafo</span>
                  <span>•</span>
                  <span>Atualizado em {{ formatDate(flow.updated_at) }}</span>
                </div>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <Button
                label="Editar Canvas"
                icon="i-lucide-edit-3"
                variant="faded"
                size="sm"
                @click="editFlow(flow.id)"
              />
              <Button
                icon="i-lucide-copy"
                variant="ghost"
                size="sm"
                title="Duplicar"
                @click="duplicateFlow(flow.id)"
              />
              <Button
                icon="i-lucide-trash-2"
                variant="ghost"
                color="ruby"
                size="sm"
                title="Excluir"
                @click="deleteFlow(flow)"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Modal de Criação de Fluxo -->
      <div
        v-if="showCreateModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
      >
        <div class="w-full max-w-md bg-n-solid-1 rounded-2xl border border-n-strong p-6 shadow-xl flex flex-col gap-4">
          <div class="flex items-center justify-between">
            <h3 class="text-base font-semibold text-n-slate-12">Novo Fluxo Conversacional</h3>
            <button
              class="text-n-slate-9 hover:text-n-slate-12"
              @click="closeCreateModal"
            >
              <Icon icon="i-lucide-x" class="size-5" />
            </button>
          </div>

          <div class="flex flex-col gap-3">
            <div>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">Nome do Fluxo *</label>
              <input
                v-model="newFlowName"
                type="text"
                placeholder="Ex: Atendimento Comercial WhatsApp"
                class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">Descrição</label>
              <textarea
                v-model="newFlowDescription"
                rows="3"
                placeholder="Ex: Menu principal de URA com opções de vendas e SAC..."
                class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand resize-none"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-n-slate-11 mb-1">Gatilho de Disparo</label>
              <select
                v-model="newFlowTrigger"
                class="w-full px-3 py-2 text-sm rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option value="default">WhatsApp Padrão (Primeira Mensagem)</option>
                <option value="kanban_stage_entered">Gatilho Kanban (Entrada de Estágio)</option>
              </select>
            </div>

            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="block text-xs font-medium text-n-slate-11">
                  Campo de Status da Conversa (Custom Attribute)
                </label>
                <button
                  v-if="!conversationAttributes || conversationAttributes.length === 0"
                  type="button"
                  class="text-[11px] text-n-brand hover:underline font-medium"
                  :disabled="isCreatingAttribute"
                  @click="createDefaultStatusAttribute"
                >
                  + Criar "etapa_fluxo"
                </button>
              </div>

              <select
                v-if="conversationAttributes && conversationAttributes.length > 0"
                v-model="newFlowStatusAttrKey"
                class="w-full px-3 py-2 text-xs rounded-lg border border-n-strong bg-n-solid-2 text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option value="">-- Não rastrear status em atributo --</option>
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
                  label="Criar 'etapa_fluxo'"
                  size="xs"
                  variant="faded"
                  :loading="isCreatingAttribute"
                  @click="createDefaultStatusAttribute"
                />
              </div>

              <p class="text-[11px] text-n-slate-10 mt-1">
                Armazena o status do passo atual na conversa para métricas de tempo e automações.
              </p>
            </div>
          </div>

          <div class="flex items-center justify-end gap-2 pt-2 border-t border-n-strong">
            <Button
              label="Cancelar"
              variant="faded"
              size="sm"
              @click="closeCreateModal"
            />
            <Button
              label="Criar e Abrir Canvas"
              icon="i-lucide-arrow-right"
              size="sm"
              :disabled="!newFlowName.trim() || isSubmitting"
              :loading="isSubmitting"
              @click="createFlow"
            />
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
