<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import customKanban from 'dashboard/api/customKanban';
import BoardView from './BoardView.vue';
import CreateBoardModal from './CreateBoardModal.vue';

const route = useRoute();
const router = useRouter();

const boards = ref([]);
const isLoading = ref(true);
const createBoardModalRef = ref(null);

const activeBoard = computed(() => {
  if (!boards.value.length) return null;
  const paramId = Number(route.params.boardId);
  if (paramId) {
    const found = boards.value.find(b => b.id === paramId);
    if (found) return found;
  }
  return boards.value[0];
});

const loadBoards = async () => {
  isLoading.value = true;
  try {
    const res = await customKanban.getBoards();
    boards.value = res.data.payload || [];
  } catch (error) {
    useAlert('Erro ao carregar quadros Kanban.');
  } finally {
    isLoading.value = false;
  }
};

const handleSelectBoard = boardId => {
  router.push({
    name: 'kanban_board_view',
    params: { boardId },
  });
};

const handleBoardCreated = newBoard => {
  boards.value.push(newBoard);
  handleSelectBoard(newBoard.id);
};

onMounted(() => {
  loadBoards();
});
</script>

<template>
  <div class="h-full w-full flex flex-col bg-slate-100 dark:bg-slate-950">
    <!-- eslint-disable vue/no-bare-strings-in-template -->
    <!-- Barra superior de ações globais do CRM -->
    <div
      class="px-6 py-2.5 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between"
    >
      <div class="flex items-center gap-2">
        <span class="text-base font-bold text-slate-800 dark:text-slate-100">
          {{ $t('KANBAN.HEADER.TITLE') }}
        </span>
        <span class="text-xs text-slate-400">
          {{ $t('KANBAN.HEADER.SUBTITLE') }}
        </span>
      </div>

      <div class="flex items-center gap-2">
        <Button
          type="button"
          size="xs"
          :label="$t('KANBAN.HEADER.NEW_BOARD')"
          @click="createBoardModalRef?.open"
        />
      </div>
    </div>

    <!-- Conteúdo Principal -->
    <div class="flex-1 overflow-hidden">
      <div
        v-if="isLoading"
        class="flex items-center justify-center h-full text-sm text-slate-400"
      >
        {{ $t('KANBAN.WIDGET.LOADING') }}
      </div>

      <div
        v-else-if="!boards.length"
        class="flex flex-col items-center justify-center h-full p-8 text-center"
      >
        <div
          class="size-16 rounded-2xl bg-woot-50 dark:bg-woot-950 flex items-center justify-center text-3xl mb-4 shadow-sm border border-woot-200 dark:border-woot-800"
        >
          <span>📊</span>
        </div>
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100">
          {{ $t('KANBAN.EMPTY_STATE.TITLE') }}
        </h3>
        <p class="text-xs text-slate-500 max-w-md mt-1 mb-6">
          {{ $t('KANBAN.EMPTY_STATE.DESCRIPTION') }}
        </p>
        <Button
          type="button"
          :label="$t('KANBAN.EMPTY_STATE.BUTTON')"
          @click="createBoardModalRef?.open"
        />
      </div>

      <BoardView
        v-else
        :board="activeBoard"
        :boards="boards"
        @select-board="handleSelectBoard"
        @board-updated="loadBoards"
      />
    </div>

    <!-- Modal Novo Quadro -->
    <CreateBoardModal ref="createBoardModalRef" @created="handleBoardCreated" />
  </div>
</template>
