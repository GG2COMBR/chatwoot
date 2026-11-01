<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  card: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['click']);
const { t } = useI18n();

const priorityBadge = computed(() => {
  switch (props.card.priority) {
    case 'urgent':
      return {
        label: t('KANBAN.CARD.PRIORITY_URGENT'),
        class: 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300',
      };
    case 'high':
      return {
        label: t('KANBAN.CARD.PRIORITY_HIGH'),
        class:
          'bg-orange-100 text-orange-700 dark:bg-orange-950 dark:text-orange-300',
      };
    case 'low':
      return {
        label: t('KANBAN.CARD.PRIORITY_LOW'),
        class:
          'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400',
      };
    default:
      return {
        label: t('KANBAN.CARD.PRIORITY_MEDIUM'),
        class:
          'bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-300',
      };
  }
});

const formattedValue = computed(() => {
  if (!props.card.value && props.card.value !== 0) return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(props.card.value);
});
</script>

<template>
  <div
    class="p-3 bg-white dark:bg-slate-900 rounded-lg border border-slate-200 dark:border-slate-800 shadow-xs hover:shadow-md hover:border-woot-400 dark:hover:border-woot-600 cursor-grab active:cursor-grabbing transition-all select-none group"
    @click="emit('click', card)"
  >
    <!-- eslint-disable vue/no-bare-strings-in-template -->
    <!-- Topo do Card: Prioridade & Status -->
    <div class="flex items-center justify-between gap-1 mb-2">
      <span
        class="px-2 py-0.5 rounded-sm text-[10px] font-semibold tracking-wide"
        :class="priorityBadge.class"
      >
        {{ priorityBadge.label }}
      </span>

      <span
        v-if="card.status === 'won'"
        class="px-1.5 py-0.5 rounded-sm text-[10px] font-semibold bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 flex items-center gap-1"
      >
        ✓ {{ $t('KANBAN.CARD.STATUS_WON') }}
      </span>
      <span
        v-else-if="card.status === 'lost'"
        class="px-1.5 py-0.5 rounded-sm text-[10px] font-semibold bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300 flex items-center gap-1"
      >
        ✕ {{ $t('KANBAN.CARD.STATUS_LOST') }}
      </span>
    </div>

    <!-- Título do Card -->
    <h4
      class="text-sm font-semibold text-slate-800 dark:text-slate-100 line-clamp-2 mb-1.5 group-hover:text-woot-600 dark:group-hover:text-woot-400"
    >
      {{ card.title }}
    </h4>

    <!-- Valor da Oportunidade -->
    <div
      v-if="card.value > 0"
      class="text-xs font-bold text-emerald-600 dark:text-emerald-400 mb-2"
    >
      {{ formattedValue }}
    </div>

    <!-- Contato e Conversa -->
    <div
      class="flex flex-col gap-1 text-[11px] text-slate-500 dark:text-slate-400 border-t border-slate-100 dark:border-slate-800/80 pt-2 mt-2"
    >
      <div v-if="card.contact" class="flex items-center gap-1.5 truncate">
        <span class="text-slate-400">👤</span>
        <span class="truncate font-medium text-slate-700 dark:text-slate-300">
          {{
            card.contact.name || card.contact.phone_number || card.contact.email
          }}
        </span>
      </div>

      <div
        v-if="card.conversation"
        class="flex items-center justify-between text-[10px] text-slate-400"
      >
        <span class="flex items-center gap-1">
          <span>💬</span> #{{ card.conversation.display_id }}
        </span>
        <span class="capitalize">
          {{ card.conversation.status }}
        </span>
      </div>
    </div>

    <!-- Rodapé: Assignees -->
    <div
      v-if="card.assignees && card.assignees.length"
      class="flex items-center justify-end gap-1 mt-2 pt-1"
    >
      <div
        v-for="user in card.assignees.slice(0, 3)"
        :key="user.id"
        class="size-5 rounded-full bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-200 flex items-center justify-center text-[10px] font-bold border border-white dark:border-slate-900"
        :title="user.name"
      >
        {{ user.name.charAt(0).toUpperCase() }}
      </div>
      <span v-if="card.assignees.length > 3" class="text-[9px] text-slate-400">
        +{{ card.assignees.length - 3 }}
      </span>
    </div>
  </div>
</template>
