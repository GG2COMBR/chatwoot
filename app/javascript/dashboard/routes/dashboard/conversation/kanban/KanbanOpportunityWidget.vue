<script setup>
import { ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import customKanban from 'dashboard/api/customKanban';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  contact: {
    type: Object,
    default: null,
  },
});

const boards = ref([]);
const currentBoard = ref(null);
const stages = ref([]);
const currentCard = ref(null);
const isLoading = ref(true);
const isUpdating = ref(false);
const isCreating = ref(false);

const newCardTitle = ref('');
const newCardValue = ref(0);
const selectedStageId = ref(null);

const loadData = async () => {
  if (!props.conversationId) return;

  isLoading.value = true;
  try {
    const boardsRes = await customKanban.getBoards();
    boards.value = boardsRes.data.payload || [];

    if (!boards.value.length) {
      isLoading.value = false;
      return;
    }

    currentBoard.value = boards.value[0];
    const stagesRes = await customKanban.getStages(currentBoard.value.id);
    stages.value = stagesRes.data.payload || [];

    const cardsRes = await customKanban.getCards(currentBoard.value.id, {});
    const allCards = cardsRes.data.payload || [];
    currentCard.value =
      allCards.find(c => c.conversation?.id === Number(props.conversationId)) ||
      null;
  } catch (error) {
    // silencioso para não poluir o painel caso a api retorne vazio
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => props.conversationId,
  () => {
    loadData();
  },
  { immediate: true }
);

const handleStageChange = async newStageId => {
  if (!currentCard.value) return;

  isUpdating.value = true;
  try {
    const res = await customKanban.moveCard(currentCard.value.id, {
      stageId: newStageId,
    });
    currentCard.value = res.data.payload;
    useAlert('Estágio do funil atualizado com sucesso!');
  } catch (error) {
    useAlert('Erro ao atualizar estágio da oportunidade.');
  } finally {
    isUpdating.value = false;
  }
};

const handleStatusChange = async newStatus => {
  if (!currentCard.value) return;

  isUpdating.value = true;
  try {
    const res = await customKanban.updateCard(currentCard.value.id, {
      status: newStatus,
    });
    currentCard.value = res.data.payload;
    useAlert('Status da oportunidade atualizado!');
  } catch (error) {
    useAlert('Erro ao atualizar status.');
  } finally {
    isUpdating.value = false;
  }
};

const handleCreateOpportunity = async () => {
  if (!currentBoard.value || !stages.value.length) return;

  isCreating.value = true;
  try {
    const title =
      newCardTitle.value.trim() ||
      `Negócio - ${props.contact?.name || 'Cliente'}`;

    const res = await customKanban.createCard(currentBoard.value.id, {
      title,
      value: Number(newCardValue.value) || 0,
      custom_kanban_stage_id: selectedStageId.value || stages.value[0]?.id,
      conversation_id: Number(props.conversationId),
      contact_id: props.contact?.id || null,
      priority: 'medium',
      status: 'open',
    });

    currentCard.value = res.data.payload;
    useAlert('Oportunidade adicionada ao funil com sucesso!');
  } catch (error) {
    useAlert('Erro ao criar oportunidade no funil.');
  } finally {
    isCreating.value = false;
  }
};
</script>

<template>
  <div class="p-3 text-xs text-slate-700 dark:text-slate-200">
    <!-- eslint-disable vue/no-bare-strings-in-template -->
    <div v-if="isLoading" class="text-center py-2 text-slate-400">
      {{ $t('KANBAN.WIDGET.LOADING') }}
    </div>

    <!-- Se já existe uma oportunidade vinculada a esta conversa -->
    <div v-else-if="currentCard" class="flex flex-col gap-3">
      <div>
        <div class="flex items-center justify-between mb-1">
          <span
            class="text-[11px] font-semibold text-slate-500 uppercase tracking-wider"
          >
            {{ $t('KANBAN.WIDGET.FUNNEL_LABEL') }}
          </span>
          <span
            class="text-[11px] font-medium text-woot-600 dark:text-woot-400"
          >
            {{ currentBoard?.name }}
          </span>
        </div>
        <p class="font-bold text-slate-800 dark:text-slate-100 text-sm">
          {{ currentCard.title }}
        </p>
      </div>

      <!-- Seletor Rápido de Estágio do Funil -->
      <div>
        <label
          class="block text-[11px] font-semibold text-slate-500 uppercase tracking-wider mb-1"
        >
          {{ $t('KANBAN.WIDGET.STAGE_LABEL') }}
        </label>
        <select
          :value="currentCard.stage_id"
          :disabled="isUpdating"
          class="w-full h-8 px-2 text-xs font-medium rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-woot-500 disabled:opacity-50"
          @change="e => handleStageChange(Number(e.target.value))"
        >
          <option v-for="stg in stages" :key="stg.id" :value="stg.id">
            {{ stg.name }}
          </option>
        </select>
      </div>

      <!-- Valor e Status -->
      <div
        class="grid grid-cols-2 gap-2 pt-1 border-t border-slate-100 dark:border-slate-800"
      >
        <div>
          <span
            class="block text-[10px] text-slate-400 uppercase font-semibold"
            >{{ $t('KANBAN.WIDGET.VALUE_LABEL') }}</span
          >
          <span class="font-bold text-emerald-600 dark:text-emerald-400">
            {{
              new Intl.NumberFormat('pt-BR', {
                style: 'currency',
                currency: 'BRL',
              }).format(currentCard.value || 0)
            }}
          </span>
        </div>

        <div>
          <span
            class="block text-[10px] text-slate-400 uppercase font-semibold"
            >{{ $t('KANBAN.WIDGET.STATUS_LABEL') }}</span
          >
          <select
            :value="currentCard.status"
            :disabled="isUpdating"
            class="h-6 text-[11px] px-1 rounded border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 font-medium"
            @change="e => handleStatusChange(e.target.value)"
          >
            <option value="open">
              {{ $t('KANBAN.HEADER.STATUS_OPEN') }}
            </option>
            <option value="won">
              {{ $t('KANBAN.HEADER.STATUS_WON') }}
            </option>
            <option value="lost">
              {{ $t('KANBAN.HEADER.STATUS_LOST') }}
            </option>
          </select>
        </div>
      </div>

      <router-link
        :to="{
          name: 'kanban_board_view',
          params: { boardId: currentBoard?.id },
        }"
        class="text-center py-1.5 px-2 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 rounded-md text-[11px] font-medium text-slate-700 dark:text-slate-300 transition-colors mt-1"
        target="_blank"
      >
        {{ $t('KANBAN.WIDGET.VIEW_BOARD') }} ↗
      </router-link>
    </div>

    <!-- Se NÃO existe oportunidade para esta conversa -->
    <div v-else class="flex flex-col gap-2.5">
      <p class="text-xs text-slate-500 dark:text-slate-400">
        {{ $t('KANBAN.WIDGET.NO_CARD_DESC') }}
      </p>

      <div class="flex flex-col gap-2 pt-1">
        <Input
          v-model="newCardTitle"
          :placeholder="`${$t('KANBAN.WIDGET.TITLE_PLACEHOLDER')} ${contact?.name || 'Cliente'}`"
          class="w-full text-xs"
        />

        <div class="grid grid-cols-2 gap-2">
          <Input
            v-model="newCardValue"
            type="number"
            step="0.01"
            placeholder="0.00"
            class="w-full text-xs"
          />

          <select
            v-model="selectedStageId"
            class="h-8 px-2 text-xs rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800"
          >
            <option v-for="stg in stages" :key="stg.id" :value="stg.id">
              {{ stg.name }}
            </option>
          </select>
        </div>

        <Button
          type="button"
          size="xs"
          :label="$t('KANBAN.WIDGET.CREATE_BUTTON')"
          :is-loading="isCreating"
          class="w-full mt-1"
          @click="handleCreateOpportunity"
        />
      </div>
    </div>
  </div>
</template>
