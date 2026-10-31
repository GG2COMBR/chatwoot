<script setup>
import { ref, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import CustomFlowsAPI from 'dashboard/api/customFlows';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

defineOptions({
  name: 'CustomFlowsEditor',
});

const route = useRoute();
const router = useRouter();

const flow = ref(null);
const isLoading = ref(true);

const fetchFlow = async () => {
  isLoading.value = true;
  try {
    const response = await CustomFlowsAPI.show(route.params.flowId);
    flow.value = response.data?.payload;
  } catch (error) {
    useAlert('Erro ao carregar detalhes do fluxo');
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchFlow();
});

const backToList = () => {
  router.push({
    name: 'custom_flows_list',
    params: { accountId: route.params.accountId },
  });
};
</script>

<template>
  <div class="flex flex-col h-full w-full bg-n-solid-1">
    <div class="flex items-center justify-between px-6 py-3 border-b border-n-strong bg-n-solid-2">
      <div class="flex items-center gap-3">
        <Button
          icon="i-lucide-arrow-left"
          variant="ghost"
          size="sm"
          @click="backToList"
        />
        <div class="flex flex-col">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ flow?.name || 'Carregando fluxo...' }}
          </h2>
          <span class="text-[11px] text-n-slate-10">
            Editor Visual Flowbuilder
          </span>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <Button
          label="Voltar para a Lista"
          variant="faint"
          size="sm"
          @click="backToList"
        />
      </div>
    </div>

    <div v-if="isLoading" class="flex-1 flex items-center justify-center">
      <Spinner />
    </div>

    <div v-else class="flex-1 flex items-center justify-center text-center p-8">
      <div class="max-w-md flex flex-col items-center">
        <div class="size-16 rounded-2xl bg-n-brand/10 text-n-brand flex items-center justify-center mb-4">
          <Icon icon="i-lucide-git-branch" class="size-8" />
        </div>
        <h3 class="text-lg font-semibold text-n-slate-12">Canvas Interativo Vue Flow</h3>
        <p class="text-xs text-n-slate-10 mt-1 mb-4">
          Pronto para renderização dos nós do grafo e catálogo interativo.
        </p>
      </div>
    </div>
  </div>
</template>
