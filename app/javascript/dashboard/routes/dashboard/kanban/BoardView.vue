<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import customKanban from 'dashboard/api/customKanban';
import KanbanStageColumn from './KanbanStageColumn.vue';
import KanbanCardModal from './KanbanCardModal.vue';

const props = defineProps({
  board: {
    type: Object,
    default: null,
  },
  boards: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['selectBoard']);

const route = useRoute();

const stages = ref([]);
const cards = ref([]);
const isLoading = ref(false);
const searchQuery = ref('');
const statusFilter = ref('');
const completedDays = ref('14');

const cardModalRef = ref(null);
const stageDialogRef = ref(null);
const newStageForm = ref({ name: '', color: '#3B82F6' });
const isCreatingStage = ref(false);

const activeBoardId = computed(() => {
  return props.board?.id || route.params.boardId;
});

const loadBoardData = async () => {
  if (!activeBoardId.value) return;

  isLoading.value = true;
  try {
    const [stagesRes, cardsRes] = await Promise.all([
      customKanban.getStages(activeBoardId.value),
      customKanban.getCards(activeBoardId.value, {
        query: searchQuery.value || undefined,
        status: statusFilter.value || undefined,
        completed_days: completedDays.value || undefined,
      }),
    ]);

    stages.value = stagesRes.data.payload || [];
    cards.value = cardsRes.data.payload || [];
  } catch (error) {
    useAlert('Erro ao carregar dados do funil.');
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => activeBoardId.value,
  newId => {
    if (newId) loadBoardData();
  },
  { immediate: true }
);

watch([searchQuery, statusFilter, completedDays], () => {
  loadBoardData();
});

const handleRemoteCardMoved = data => {
  if (!data || (data.board_id && data.board_id !== Number(activeBoardId.value)))
    return;
  const targetCard = cards.value.find(c => c.id === data.card_id);
  if (targetCard) {
    targetCard.stage_id = data.stage_id;
    if (data.position !== undefined) targetCard.position = data.position;
  } else {
    loadBoardData();
  }
};

onMounted(() => {
  emitter.on(BUS_EVENTS.KANBAN_CARD_MOVED, handleRemoteCardMoved);
});

onUnmounted(() => {
  emitter.off(BUS_EVENTS.KANBAN_CARD_MOVED, handleRemoteCardMoved);
});

const filteredCardsByStage = stageId => {
  return cards.value.filter(c => c.stage_id === stageId);
};

const totalPipelineValue = computed(() => {
  const sum = cards.value.reduce(
    (acc, c) => acc + (parseFloat(c.value) || 0),
    0
  );
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(sum);
});

const wonCardsCount = computed(() => {
  return cards.value.filter(c => c.status === 'won').length;
});

const handleCardClick = card => {
  cardModalRef.value?.open(card);
};

const handleAddCard = stageId => {
  cardModalRef.value?.open(null, stageId);
};

const handleCardSaved = savedCard => {
  const index = cards.value.findIndex(c => c.id === savedCard.id);
  if (index !== -1) {
    cards.value.splice(index, 1, savedCard);
  } else {
    cards.value.push(savedCard);
  }
};

const handleCardDeleted = cardId => {
  cards.value = cards.value.filter(c => c.id !== cardId);
};

const handleDragCardsChange = async ({ stageId, event }) => {
  if (event.added) {
    const movedCard = event.added.element;
    const newPosition = event.added.newIndex;
    movedCard.stage_id = stageId;

    try {
      await customKanban.moveCard(movedCard.id, {
        stageId,
        position: newPosition,
      });
    } catch (error) {
      useAlert('Erro ao mover oportunidade. Recarregando...');
      loadBoardData();
    }
  } else if (event.moved) {
    const movedCard = event.moved.element;
    const newPosition = event.moved.newIndex;
    try {
      await customKanban.moveCard(movedCard.id, {
        stageId,
        position: newPosition,
      });
    } catch (error) {
      loadBoardData();
    }
  }
};

const openCreateStage = () => {
  newStageForm.value = { name: '', color: '#3B82F6' };
  stageDialogRef.value?.open();
};

const handleSaveStage = async () => {
  if (!newStageForm.value.name.trim() || !activeBoardId.value) return;
  isCreatingStage.value = true;
  try {
    const res = await customKanban.createStage(activeBoardId.value, {
      name: newStageForm.value.name,
      color: newStageForm.value.color,
      position: stages.value.length,
    });
    stages.value.push(res.data.payload);
    stageDialogRef.value?.close();
    useAlert('Nova etapa adicionada ao funil!');
  } catch (error) {
    useAlert('Erro ao adicionar etapa.');
  } finally {
    isCreatingStage.value = false;
  }
};
</script>

<template>
  <div
    class="flex flex-col h-full w-full bg-white dark:bg-slate-950 overflow-hidden"
  >
    <!-- eslint-disable vue/no-bare-strings-in-template -->
    <!-- Cabeçalho Principal do Kanban -->
    <header
      class="p-4 border-b border-slate-200 dark:border-slate-800 flex flex-wrap items-center justify-between gap-4"
    >
      <div class="flex items-center gap-3">
        <!-- Seletor de Quadro / Funil -->
        <div class="flex items-center gap-2">
          <span class="text-xl">📊</span>
          <select
            v-if="boards && boards.length"
            :value="board?.id"
            class="h-9 px-3 font-bold text-sm bg-slate-100 dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 focus:outline-none focus:ring-2 focus:ring-woot-500 cursor-pointer"
            @change="e => emit('selectBoard', Number(e.target.value))"
          >
            <option v-for="b in boards" :key="b.id" :value="b.id">
              {{ b.name }}
            </option>
          </select>
          <span
            v-else
            class="font-bold text-sm text-slate-800 dark:text-slate-100"
          >
            {{ board?.name || $t('KANBAN.HEADER.TITLE') }}
          </span>
        </div>

        <!-- Indicador de sincronia -->
        <span
          v-if="board?.sync_attribute_key"
          class="hidden md:inline-flex items-center gap-1 px-2 py-0.5 rounded text-[11px] font-medium bg-woot-50 dark:bg-woot-950/60 text-woot-700 dark:text-woot-300 border border-woot-200 dark:border-woot-800"
          :title="`${$t('KANBAN.HEADER.SYNCED_WITH')} ${board.sync_attribute_key}`"
        >
          🔄 {{ board.sync_attribute_key }}
        </span>
      </div>

      <!-- Métricas Resumo -->
      <div
        class="hidden lg:flex items-center gap-6 px-4 py-1.5 bg-slate-50 dark:bg-slate-900 rounded-lg border border-slate-200/80 dark:border-slate-800 text-xs"
      >
        <div>
          <span class="text-slate-400">{{
            $t('KANBAN.HEADER.TOTAL_OPPORTUNITIES')
          }}</span>
          <span class="ml-1.5 font-bold text-slate-700 dark:text-slate-200">{{
            cards.length
          }}</span>
        </div>
        <div class="h-4 w-px bg-slate-200 dark:bg-slate-700" />
        <div>
          <span class="text-slate-400">{{
            $t('KANBAN.HEADER.PIPELINE_VALUE')
          }}</span>
          <span class="ml-1.5 font-bold text-emerald-600 dark:text-emerald-400">
            {{ totalPipelineValue }}
          </span>
        </div>
        <div class="h-4 w-px bg-slate-200 dark:bg-slate-700" />
        <div>
          <span class="text-slate-400">{{
            $t('KANBAN.HEADER.CLOSED_WON')
          }}</span>
          <span class="ml-1.5 font-bold text-woot-600 dark:text-woot-400">{{
            wonCardsCount
          }}</span>
        </div>
      </div>

      <!-- Filtros e Ações -->
      <div class="flex items-center gap-2">
        <div class="relative w-44 sm:w-56">
          <Input
            v-model="searchQuery"
            :placeholder="$t('KANBAN.HEADER.SEARCH_PLACEHOLDER')"
            class="w-full text-xs"
          />
        </div>

        <select
          v-model="statusFilter"
          class="h-8 px-2 text-xs bg-slate-100 dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 focus:outline-none focus:ring-2 focus:ring-woot-500"
        >
          <option value="">
            {{ $t('KANBAN.HEADER.STATUS_ALL') }}
          </option>
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

        <select
          v-model="completedDays"
          class="h-8 px-2 text-xs bg-slate-100 dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 focus:outline-none focus:ring-2 focus:ring-woot-500"
          :title="$t('KANBAN.HEADER.WINDOW_LABEL')"
        >
          <option value="7">
            {{ $t('KANBAN.HEADER.WINDOW_7') }}
          </option>
          <option value="14">
            {{ $t('KANBAN.HEADER.WINDOW_14') }}
          </option>
          <option value="30">
            {{ $t('KANBAN.HEADER.WINDOW_30') }}
          </option>
          <option value="all">
            {{ $t('KANBAN.HEADER.WINDOW_ALL') }}
          </option>
        </select>

        <Button
          type="button"
          size="sm"
          :label="$t('KANBAN.HEADER.NEW_OPPORTUNITY')"
          @click="() => handleAddCard(stages[0]?.id)"
        />
      </div>
    </header>

    <!-- Área de Colunas (Scroll Horizontal) -->
    <main class="flex-1 p-4 overflow-x-auto overflow-y-hidden">
      <div
        v-if="isLoading"
        class="flex items-center justify-center h-64 text-sm text-slate-400"
      >
        {{ $t('KANBAN.WIDGET.LOADING') }}
      </div>

      <div
        v-else-if="!stages.length"
        class="flex flex-col items-center justify-center h-64 text-center p-6 border-2 border-dashed border-slate-200 dark:border-slate-800 rounded-xl"
      >
        <span class="text-3xl mb-2">📋</span>
        <h4 class="font-semibold text-slate-700 dark:text-slate-200 text-sm">
          {{ $t('KANBAN.EMPTY_STATE.NO_STAGES_TITLE') }}
        </h4>
        <p class="text-xs text-slate-400 mt-1 max-w-sm">
          {{ $t('KANBAN.EMPTY_STATE.NO_STAGES_DESCRIPTION') }}
        </p>
        <Button
          type="button"
          size="sm"
          :label="$t('KANBAN.EMPTY_STATE.ADD_STAGE_BUTTON')"
          class="mt-4"
          @click="openCreateStage"
        />
      </div>

      <div v-else class="flex items-start gap-4 h-full pb-2">
        <KanbanStageColumn
          v-for="stage in stages"
          :key="stage.id"
          :stage="stage"
          :cards="filteredCardsByStage(stage.id)"
          @card-click="handleCardClick"
          @add-card="handleAddCard"
          @change-cards="handleDragCardsChange"
        />

        <!-- Botão Adicionar Coluna -->
        <button
          type="button"
          class="flex-shrink-0 w-72 h-32 flex flex-col items-center justify-center border-2 border-dashed border-slate-200 dark:border-slate-800 hover:border-woot-400 dark:hover:border-woot-600 rounded-xl text-slate-400 hover:text-woot-600 dark:hover:text-woot-400 transition-all text-xs font-semibold gap-1.5"
          @click="openCreateStage"
        >
          <span class="text-lg font-bold leading-none">+</span>
          {{ $t('KANBAN.EMPTY_STATE.ADD_NEW_STAGE') }}
        </button>
      </div>
    </main>

    <!-- Modal de Card / Oportunidade -->
    <KanbanCardModal
      ref="cardModalRef"
      :board-id="activeBoardId"
      :stages="stages"
      @saved="handleCardSaved"
      @deleted="handleCardDeleted"
    />

    <!-- Dialog de Nova Etapa -->
    <Dialog
      ref="stageDialogRef"
      :title="$t('KANBAN.EMPTY_STATE.ADD_NEW_STAGE')"
      confirm-button-label="Salvar"
      :is-loading="isCreatingStage"
      @confirm="handleSaveStage"
    >
      <div
        class="flex flex-col gap-3 py-2 text-sm text-slate-800 dark:text-slate-100"
      >
        <div>
          <label
            class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
          >
            {{ $t('KANBAN.EMPTY_STATE.STAGE_NAME_LABEL') }}
          </label>
          <Input
            v-model="newStageForm.name"
            :placeholder="$t('KANBAN.EMPTY_STATE.STAGE_NAME_PLACEHOLDER')"
            class="w-full"
          />
        </div>

        <div>
          <label
            class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
          >
            {{ $t('KANBAN.EMPTY_STATE.STAGE_COLOR_LABEL') }}
          </label>
          <div class="flex items-center gap-2">
            <input
              v-model="newStageForm.color"
              type="color"
              class="size-8 rounded border border-slate-300 dark:border-slate-700 cursor-pointer"
            />
            <span class="text-xs text-slate-500">{{ newStageForm.color }}</span>
          </div>
        </div>
      </div>
    </Dialog>
  </div>
</template>
