<script setup>
import { computed } from 'vue';
import Draggable from 'vuedraggable';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  stage: {
    type: Object,
    required: true,
  },
  cards: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['cardClick', 'addCard', 'changeCards']);

const columnTotalValue = computed(() => {
  const sum = props.cards.reduce(
    (acc, c) => acc + (parseFloat(c.value) || 0),
    0
  );
  if (!sum) return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(sum);
});

const onDragChange = event => {
  emit('changeCards', { stageId: props.stage.id, event });
};
</script>

<template>
  <div
    class="flex flex-col flex-shrink-0 w-80 bg-slate-50 dark:bg-slate-900/60 rounded-xl border border-slate-200 dark:border-slate-800 h-full max-h-[calc(100vh-180px)] shadow-xs"
  >
    <!-- eslint-disable vue/no-bare-strings-in-template -->
    >
    <!-- Cabeçalho da Coluna -->
    <div
      class="p-3.5 border-b border-slate-200/80 dark:border-slate-800 flex items-center justify-between"
    >
      <div class="flex items-center gap-2 truncate">
        <span
          class="size-2.5 rounded-full flex-shrink-0"
          :style="{ backgroundColor: stage.color || '#3B82F6' }"
        />
        <h3
          class="font-semibold text-xs text-slate-800 dark:text-slate-100 truncate"
        >
          {{ stage.name }}
        </h3>
        <span
          class="px-1.5 py-0.2 rounded-full text-[10px] font-bold bg-slate-200 dark:bg-slate-800 text-slate-600 dark:text-slate-300"
        >
          {{ cards.length }}
        </span>
      </div>

      <div class="flex items-center gap-1">
        <button
          type="button"
          class="p-1 rounded-md text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-800 transition-colors"
          :title="$t('KANBAN.COLUMN.NEW_OPP_TOOLTIP')"
          @click="emit('addCard', stage.id)"
        >
          <span class="text-sm font-bold leading-none">+</span>
        </button>
      </div>
    </div>

    <!-- Sub-header: Valor total da coluna -->
    <div
      v-if="columnTotalValue"
      class="px-3.5 py-1 text-[11px] font-medium text-slate-500 dark:text-slate-400 bg-slate-100/60 dark:bg-slate-800/40 border-b border-slate-200/60 dark:border-slate-800/60"
    >
      {{ $t('KANBAN.COLUMN.TOTAL') }}
      <span class="font-semibold text-slate-700 dark:text-slate-200">{{
        columnTotalValue
      }}</span>
    </div>

    <!-- Lista de Cards Arrastáveis -->
    <div class="flex-1 p-2 overflow-y-auto">
      <Draggable
        :list="cards"
        group="kanban-cards"
        item-key="id"
        class="flex flex-col gap-2.5 min-h-[100px] h-full"
        ghost-class="opacity-40 scale-98"
        animation="200"
        @change="onDragChange"
      >
        <template #item="{ element }">
          <KanbanCard
            :card="element"
            @click="card => emit('cardClick', card)"
          />
        </template>
      </Draggable>
    </div>

    <!-- Rodapé: Adicionar Oportunidade Rápido -->
    <div class="p-2 border-t border-slate-200/60 dark:border-slate-800/60">
      <button
        type="button"
        class="w-full py-2 px-3 text-xs font-medium text-slate-500 hover:text-woot-600 dark:text-slate-400 dark:hover:text-woot-400 hover:bg-white dark:hover:bg-slate-800 rounded-lg transition-all border border-dashed border-slate-300 dark:border-slate-700 hover:border-woot-400 flex items-center justify-center gap-1.5"
        @click="emit('addCard', stage.id)"
      >
        <span class="text-sm font-bold">+</span>
        {{ $t('KANBAN.COLUMN.ADD_OPPORTUNITY') }}
      </button>
    </div>
  </div>
</template>
