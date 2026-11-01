<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import customKanban from 'dashboard/api/customKanban';

const emit = defineEmits(['created']);

const store = useStore();
const dialogRef = ref(null);
const isSubmitting = ref(false);

const form = ref({
  name: '',
  description: '',
  sync_attribute_key: '',
  auto_create_cards: false,
});

const conversationAttributes = computed(() => {
  return (
    store.getters['attributes/getCustomAttributesByModel'](
      'conversation_attribute'
    ) || []
  );
});

const open = () => {
  form.value = {
    name: '',
    description: '',
    sync_attribute_key: '',
    auto_create_cards: false,
  };
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
};

const handleSave = async () => {
  if (!form.value.name.trim()) {
    useAlert('Por favor, informe o nome do quadro.');
    return;
  }

  isSubmitting.value = true;
  try {
    const payload = {
      name: form.value.name,
      description: form.value.description,
      sync_attribute_key: form.value.sync_attribute_key || null,
      auto_create_cards: form.value.auto_create_cards,
      stages_attributes: [
        { name: 'Lead / Contato', slug: 'lead', position: 0, color: '#3B82F6' },
        {
          name: 'Qualificação',
          slug: 'qualificacao',
          position: 1,
          color: '#F59E0B',
        },
        {
          name: 'Negociação',
          slug: 'negociacao',
          position: 2,
          color: '#8B5CF6',
        },
        {
          name: 'Fechado / Ganho',
          slug: 'ganho',
          position: 3,
          color: '#10B981',
        },
      ],
    };

    const response = await customKanban.createBoard(payload);
    useAlert('Quadro Kanban criado com sucesso!');
    emit('created', response.data.payload);
    close();
  } catch (error) {
    useAlert(
      'Erro ao criar quadro Kanban: ' +
        (error.response?.data?.error || error.message)
    );
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t('KANBAN.BOARD_MODAL.TITLE')"
    :description="$t('KANBAN.BOARD_MODAL.DESCRIPTION')"
    :confirm-button-label="$t('KANBAN.BOARD_MODAL.SUBMIT_BUTTON')"
    :is-loading="isSubmitting"
    @confirm="handleSave"
  >
    <!-- eslint-disable vue/no-bare-strings-in-template -->
    <div
      class="flex flex-col gap-4 py-2 text-sm text-slate-800 dark:text-slate-100"
    >
      <div>
        <label
          class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
        >
          {{ $t('KANBAN.BOARD_MODAL.NAME_LABEL') }}
        </label>
        <Input
          v-model="form.name"
          :placeholder="$t('KANBAN.BOARD_MODAL.NAME_PLACEHOLDER')"
          class="w-full"
        />
      </div>

      <div>
        <label
          class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
        >
          {{ $t('KANBAN.BOARD_MODAL.DESC_LABEL') }}
        </label>
        <Input
          v-model="form.description"
          :placeholder="$t('KANBAN.BOARD_MODAL.DESC_PLACEHOLDER')"
          class="w-full"
        />
      </div>

      <div>
        <label
          class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
        >
          {{ $t('KANBAN.BOARD_MODAL.SYNC_ATTR_LABEL') }}
        </label>
        <select
          v-model="form.sync_attribute_key"
          class="w-full h-10 px-3 border rounded-lg bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
        >
          <option value="">
            {{ $t('KANBAN.BOARD_MODAL.SYNC_ATTR_NONE') }}
          </option>
          <option
            v-for="attr in conversationAttributes"
            :key="attr.attribute_key"
            :value="attr.attribute_key"
          >
            {{ attr.attribute_display_name }} ({{ attr.attribute_key }})
          </option>
        </select>
        <p class="mt-1 text-xs text-slate-500">
          {{ $t('KANBAN.BOARD_MODAL.SYNC_ATTR_HELP') }}
        </p>
      </div>

      <div class="flex items-center gap-2 pt-2">
        <input
          id="auto-create-cards"
          v-model="form.auto_create_cards"
          type="checkbox"
          class="size-4 rounded border-slate-300 text-woot-600 focus:ring-woot-500"
        />
        <label
          for="auto-create-cards"
          class="text-xs text-slate-700 dark:text-slate-300"
        >
          {{ $t('KANBAN.BOARD_MODAL.AUTO_CREATE_CARDS') }}
        </label>
      </div>
    </div>
  </Dialog>
</template>
