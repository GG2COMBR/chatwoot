<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  selectedTeam: {
    type: Object,
    default: null,
  },
  teams: {
    type: Array,
    default: () => [],
  },
  showTeamsDropdown: {
    type: Boolean,
    default: false,
  },
  selectedStatus: {
    type: String,
    default: 'open',
  },
  showStatusDropdown: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'updateTeam',
  'toggleTeamsDropdown',
  'updateStatus',
  'toggleStatusDropdown',
]);

const { t } = useI18n();

const teamMenuItems = computed(() => {
  return props.teams.map(team => ({
    label: team.name,
    value: team.id,
    icon: 'i-lucide-users-round',
  }));
});

const statusMenuItems = computed(() => [
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT'),
    value: 'open',
    icon: 'i-lucide-circle-dot',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT'),
    value: 'pending',
    icon: 'i-lucide-clock',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT'),
    value: 'snoozed',
    icon: 'i-lucide-alarm-clock',
  },
]);

const currentStatusLabel = computed(() => {
  const item = statusMenuItems.value.find(
    s => s.value === props.selectedStatus
  );
  return item ? item.label : t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT');
});

const handleTeamAction = item => {
  const team = props.teams.find(tm => tm.id === item.value) || {
    id: item.value,
    name: item.label,
  };
  emit('updateTeam', team);
  emit('toggleTeamsDropdown', false);
};

const handleStatusAction = item => {
  emit('updateStatus', item.value);
  emit('toggleStatusDropdown', false);
};
</script>

<template>
  <div
    class="flex flex-wrap items-center justify-between flex-1 w-full gap-3 px-4 py-2.5 overflow-y-visible border-b border-n-strong"
  >
    <!-- Team Selection -->
    <div class="flex items-center gap-3">
      <label
        class="mb-0.5 text-sm font-medium text-n-slate-11 whitespace-nowrap"
      >
        {{ t('COMPOSE_NEW_CONVERSATION.FORM.TEAM_SELECTOR.LABEL') }}
      </label>

      <div
        v-if="selectedTeam"
        class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 truncate h-7 min-w-0 px-2"
      >
        <Icon
          icon="i-lucide-users-round"
          class="size-3.5 text-n-slate-11 flex-shrink-0"
        />
        <span class="text-sm truncate text-n-slate-12">
          {{ selectedTeam.name }}
        </span>
        <Button
          variant="ghost"
          icon="i-lucide-x"
          color="slate"
          size="xs"
          class="flex-shrink-0"
          @click="emit('updateTeam', null)"
        />
      </div>

      <div
        v-else
        v-on-click-outside="() => emit('toggleTeamsDropdown', false)"
        class="relative flex items-center h-7"
      >
        <Button
          :label="t('COMPOSE_NEW_CONVERSATION.FORM.TEAM_SELECTOR.BUTTON')"
          variant="link"
          size="sm"
          color="slate"
          class="hover:!no-underline"
          :disabled="teams.length === 0"
          @click="emit('toggleTeamsDropdown', !showTeamsDropdown)"
        />
        <DropdownMenu
          v-if="teamMenuItems.length > 0 && showTeamsDropdown"
          :menu-items="teamMenuItems"
          class="ltr:left-0 rtl:right-0 z-[100] top-8 max-h-56 w-fit max-w-sm dark:!outline-n-slate-5"
          @action="handleTeamAction"
        />
      </div>
    </div>

    <!-- Status Selection -->
    <div
      v-on-click-outside="() => emit('toggleStatusDropdown', false)"
      class="relative flex items-center gap-2 h-7"
    >
      <label
        class="mb-0.5 text-sm font-medium text-n-slate-11 whitespace-nowrap"
      >
        {{ t('COMPOSE_NEW_CONVERSATION.FORM.STATUS_SELECTOR.LABEL') }}
      </label>
      <Button
        :label="currentStatusLabel"
        variant="ghost"
        size="xs"
        color="slate"
        icon="i-lucide-chevron-down"
        trailing-icon
        class="border border-n-strong"
        @click="emit('toggleStatusDropdown', !showStatusDropdown)"
      />
      <DropdownMenu
        v-if="showStatusDropdown"
        :menu-items="statusMenuItems"
        class="ltr:right-0 rtl:left-0 z-[100] top-8 max-h-56 w-fit min-w-[8rem] dark:!outline-n-slate-5"
        @action="handleStatusAction"
      />
    </div>
  </div>
</template>
