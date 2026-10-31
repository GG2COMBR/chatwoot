<script setup>
import { ref, onMounted, markRaw } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import CustomFlowsAPI from 'dashboard/api/customFlows';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CustomNode from './components/CustomNode.vue';
import BlockCatalog from './components/BlockCatalog.vue';
import NodeConfigDrawer from './components/NodeConfigDrawer.vue';
import WhatsAppSimulator from './components/WhatsAppSimulator.vue';

import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';

defineOptions({
  name: 'CustomFlowsEditor',
});

const route = useRoute();
const router = useRouter();

const flow = ref(null);
const isLoading = ref(true);
const isSaving = ref(false);
const isPublishing = ref(false);

const nodes = ref([]);
const edges = ref([]);

const selectedNode = ref(null);
const isDrawerOpen = ref(false);
const isSimulatorOpen = ref(false);

const nodeTypes = {
  start: markRaw(CustomNode),
  message: markRaw(CustomNode),
  interactive_buttons: markRaw(CustomNode),
  interactive_list: markRaw(CustomNode),
  business_hours: markRaw(CustomNode),
  ai_fallback: markRaw(CustomNode),
  ai_agent: markRaw(CustomNode),
  human_transfer: markRaw(CustomNode),
  kanban_stage_change: markRaw(CustomNode),
  async_api: markRaw(CustomNode),
  finish: markRaw(CustomNode),
};

const { addEdges, removeNodes } = useVueFlow();

const fetchFlow = async () => {
  isLoading.value = true;
  try {
    const response = await CustomFlowsAPI.show(route.params.flowId);
    flow.value = response.data?.payload;

    nodes.value = (flow.value?.nodes || []).map(n => ({
      ...n,
      type: n.type || 'message',
    }));
    edges.value = flow.value?.edges || [];
  } catch (error) {
    useAlert('Erro ao carregar detalhes do fluxo');
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchFlow();
});

const onConnect = params => {
  addEdges([
    {
      ...params,
      id: `e_${params.source}_${params.target}_${Date.now()}`,
      animated: true,
    },
  ]);
};

const onNodeClick = ({ node }) => {
  selectedNode.value = node;
  isDrawerOpen.value = true;
};

const handleAddNode = ({ type, data }) => {
  const newNodeId = `node_${Date.now()}`;
  const offset = nodes.value.length;
  const newNode = {
    id: newNodeId,
    type,
    position: {
      x: 340 + (offset % 2) * 50,
      y: 120 + offset * 70,
    },
    data,
  };

  nodes.value.push(newNode);
  selectedNode.value = newNode;
  isDrawerOpen.value = true;
};

const handleUpdateNode = updatedNode => {
  const index = nodes.value.findIndex(n => n.id === updatedNode.id);
  if (index !== -1) {
    nodes.value[index] = { ...updatedNode };
    selectedNode.value = nodes.value[index];
  }
};

const handleDeleteNode = nodeId => {
  if (selectedNode.value?.id === nodeId) {
    isDrawerOpen.value = false;
    selectedNode.value = null;
  }
  removeNodes([nodeId]);
  nodes.value = nodes.value.filter(n => n.id !== nodeId);
};

const closeDrawer = () => {
  isDrawerOpen.value = false;
  selectedNode.value = null;
};

const saveFlow = async () => {
  isSaving.value = true;
  try {
    const payload = {
      custom_flow: {
        nodes: nodes.value,
        edges: edges.value,
      },
    };
    await CustomFlowsAPI.update(flow.value.id, payload);
    useAlert('Fluxo salvo com sucesso!');
  } catch (error) {
    useAlert('Falha ao salvar o fluxo');
  } finally {
    isSaving.value = false;
  }
};

const publishFlow = async () => {
  isPublishing.value = true;
  try {
    await saveFlow();
    await CustomFlowsAPI.publish(flow.value.id);
    if (flow.value) {
      flow.value.status = 'published';
    }
    useAlert('Fluxo publicado com sucesso!');
  } catch (error) {
    const errorMsg = error?.response?.data?.error || 'Falha ao publicar fluxo';
    useAlert(errorMsg);
  } finally {
    isPublishing.value = false;
  }
};

const backToList = () => {
  router.push({
    name: 'custom_flows_list',
    params: { accountId: route.params.accountId },
  });
};
</script>

<template>
  <div class="flex flex-col flex-1 h-full w-full min-h-0 bg-n-solid-1 overflow-hidden relative">
    <!-- Topbar do Editor -->
    <div class="flex items-center justify-between px-6 py-3 border-b border-n-strong bg-n-solid-2 shrink-0 z-10 shadow-sm">
      <div class="flex items-center gap-4">
        <Button
          icon="i-lucide-arrow-left"
          variant="ghost"
          size="sm"
          @click="backToList"
        />

        <div class="flex items-center gap-2">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ flow?.name || 'Carregando...' }}
          </h2>
          <span
            v-if="flow"
            class="text-[10px] font-medium px-2 py-0.5 rounded-full"
            :class="flow.status === 'published' ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20' : 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20'"
          >
            {{ flow.status === 'published' ? 'Publicado' : 'Rascunho' }}
          </span>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <Button
          label="Testar Fluxo"
          icon="i-lucide-play"
          variant="faded"
          size="sm"
          @click="isSimulatorOpen = true"
        />
        <Button
          label="Salvar Alterações"
          icon="i-lucide-save"
          variant="faded"
          size="sm"
          :loading="isSaving"
          @click="saveFlow"
        />
        <Button
          label="Publicar Fluxo"
          icon="i-lucide-upload-cloud"
          size="sm"
          :loading="isPublishing"
          @click="publishFlow"
        />
      </div>
    </div>

    <!-- Canvas Principal com Vue Flow -->
    <div class="flex-1 w-full h-full min-h-0 relative" style="min-height: 500px;">
      <div v-if="isLoading" class="absolute inset-0 flex items-center justify-center bg-n-solid-1/80 z-20">
        <Spinner />
      </div>

      <!-- Catálogo Flutuante de Blocos -->
      <BlockCatalog @add-node="handleAddNode" />

      <!-- Painel Lateral Deslizante de Configuração do Nó -->
      <NodeConfigDrawer
        :is-open="isDrawerOpen"
        :node="selectedNode"
        @close="closeDrawer"
        @update="handleUpdateNode"
      />

      <!-- Simulador de WhatsApp -->
      <WhatsAppSimulator
        :is-open="isSimulatorOpen"
        :nodes="nodes"
        :edges="edges"
        @close="isSimulatorOpen = false"
      />

      <VueFlow
        v-model:nodes="nodes"
        v-model:edges="edges"
        :node-types="nodeTypes"
        :default-viewport="{ zoom: 1 }"
        :min-zoom="0.2"
        :max-zoom="2"
        fit-view-on-init
        class="h-full w-full"
        style="width: 100%; height: 100%; min-height: 500px;"
        @connect="onConnect"
        @node-click="onNodeClick"
      >
        <template #node-start="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>
        <template #node-message="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>
        <template #node-interactive_buttons="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>
        <template #node-interactive_list="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>
        <template #node-business_hours="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>
        <template #node-ai_fallback="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>
        <template #node-human_transfer="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>
        <template #node-kanban_stage_change="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>
        <template #node-async_api="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>
        <template #node-finish="nodeProps">
          <CustomNode v-bind="nodeProps" @delete="handleDeleteNode" />
        </template>

        <Background :gap="16" />
        <Controls position="bottom-left" />
      </VueFlow>
    </div>
  </div>
</template>
