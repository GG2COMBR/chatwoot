<script setup>
import { ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import customKanban from 'dashboard/api/customKanban';

const props = defineProps({
  boardId: {
    type: [Number, String],
    required: true,
  },
  stages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['saved', 'deleted']);

const dialogRef = ref(null);
const isSubmitting = ref(false);
const activeTab = ref('details');
const newNoteContent = ref('');
const isAddingNote = ref(false);

const card = ref(null);
const form = ref({
  id: null,
  title: '',
  description: '',
  value: 0,
  priority: 'medium',
  status: 'open',
  custom_kanban_stage_id: null,
  contact_id: null,
  assignee_ids: [],
});

const notes = ref([]);

const open = async (cardData = null, defaultStageId = null) => {
  activeTab.value = 'details';
  newNoteContent.value = '';

  if (cardData && cardData.id) {
    card.value = cardData;
    form.value = {
      id: cardData.id,
      title: cardData.title || '',
      description: cardData.description || '',
      value: cardData.value || 0,
      priority: cardData.priority || 'medium',
      status: cardData.status || 'open',
      custom_kanban_stage_id: cardData.stage_id,
      contact_id: cardData.contact?.id || null,
      assignee_ids: (cardData.assignees || []).map(a => a.id),
    };
    try {
      const res = await customKanban.getNotes(cardData.id);
      notes.value = res.data.payload || [];
    } catch (err) {
      notes.value = [];
    }
  } else {
    card.value = null;
    form.value = {
      id: null,
      title: '',
      description: '',
      value: 0,
      priority: 'medium',
      status: 'open',
      custom_kanban_stage_id: defaultStageId || props.stages[0]?.id || null,
      contact_id: null,
      assignee_ids: [],
    };
    notes.value = [];
  }

  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
};

const handleSave = async () => {
  if (!form.value.title.trim()) {
    useAlert('Por favor, informe o título da oportunidade.');
    return;
  }

  isSubmitting.value = true;
  try {
    let savedCard = null;
    if (form.value.id) {
      const res = await customKanban.updateCard(form.value.id, form.value);
      savedCard = res.data.payload;
      useAlert('Oportunidade atualizada com sucesso!');
    } else {
      const res = await customKanban.createCard(props.boardId, form.value);
      savedCard = res.data.payload;
      useAlert('Oportunidade criada com sucesso!');
    }
    emit('saved', savedCard);
    close();
  } catch (error) {
    useAlert(
      'Erro ao salvar oportunidade: ' +
        (error.response?.data?.error || error.message)
    );
  } finally {
    isSubmitting.value = false;
  }
};

const handleDelete = async () => {
  if (!form.value.id) return;
  // eslint-disable-next-line no-alert
  if (!window.confirm('Deseja realmente excluir esta oportunidade?')) return;

  isSubmitting.value = true;
  try {
    await customKanban.deleteCard(form.value.id);
    useAlert('Oportunidade excluída com sucesso.');
    emit('deleted', form.value.id);
    close();
  } catch (error) {
    useAlert(
      'Erro ao excluir oportunidade: ' +
        (error.response?.data?.error || error.message)
    );
  } finally {
    isSubmitting.value = false;
  }
};

const handleAddNote = async () => {
  if (!newNoteContent.value.trim() || !form.value.id) return;
  isAddingNote.value = true;
  try {
    const res = await customKanban.createNote(
      form.value.id,
      newNoteContent.value
    );
    notes.value.unshift(res.data.payload);
    newNoteContent.value = '';
    useAlert('Anotação adicionada!');
  } catch (error) {
    useAlert('Erro ao adicionar anotação.');
  } finally {
    isAddingNote.value = false;
  }
};

const handleDeleteNote = async noteId => {
  try {
    await customKanban.deleteNote(form.value.id, noteId);
    notes.value = notes.value.filter(n => n.id !== noteId);
  } catch (err) {
    useAlert('Erro ao excluir anotação.');
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      form.id ? $t('KANBAN.MODAL.EDIT_TITLE') : $t('KANBAN.MODAL.CREATE_TITLE')
    "
    :confirm-button-label="$t('KANBAN.MODAL.SAVE_BUTTON')"
    :is-loading="isSubmitting"
    @confirm="handleSave"
  >
    <!-- eslint-disable vue/no-bare-strings-in-template -->
    <div
      class="flex flex-col gap-4 py-1 text-sm text-slate-800 dark:text-slate-100"
    >
      <!-- Tabs quando editando -->
      <div
        v-if="form.id"
        class="flex border-b border-slate-200 dark:border-slate-700 mb-2"
      >
        <button
          type="button"
          class="px-4 py-2 font-medium text-xs border-b-2 transition-colors"
          :class="
            activeTab === 'details'
              ? 'border-woot-500 text-woot-600 dark:text-woot-400 font-semibold'
              : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
          "
          @click="activeTab = 'details'"
        >
          {{ $t('KANBAN.MODAL.TAB_DETAILS') }}
        </button>
        <button
          type="button"
          class="px-4 py-2 font-medium text-xs border-b-2 transition-colors flex items-center gap-1.5"
          :class="
            activeTab === 'notes'
              ? 'border-woot-500 text-woot-600 dark:text-woot-400 font-semibold'
              : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
          "
          @click="activeTab = 'notes'"
        >
          {{ $t('KANBAN.MODAL.TAB_NOTES') }}
          <span
            v-if="notes.length"
            class="px-1.5 py-0.2 rounded-full text-[10px] bg-slate-200 dark:bg-slate-700"
          >
            {{ notes.length }}
          </span>
        </button>
      </div>

      <!-- Tab: Detalhes -->
      <div v-show="activeTab === 'details'" class="flex flex-col gap-3">
        <div>
          <label
            class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
          >
            {{ $t('KANBAN.MODAL.TITLE_LABEL') }}
          </label>
          <Input
            v-model="form.title"
            :placeholder="$t('KANBAN.MODAL.TITLE_PLACEHOLDER')"
            class="w-full"
          />
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label
              class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
            >
              {{ $t('KANBAN.MODAL.VALUE_LABEL') }}
            </label>
            <Input
              v-model="form.value"
              type="number"
              step="0.01"
              placeholder="0,00"
              class="w-full"
            />
          </div>

          <div>
            <label
              class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
            >
              {{ $t('KANBAN.MODAL.STAGE_LABEL') }}
            </label>
            <select
              v-model="form.custom_kanban_stage_id"
              class="w-full h-10 px-3 border rounded-lg bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
            >
              <option v-for="stg in stages" :key="stg.id" :value="stg.id">
                {{ stg.name }}
              </option>
            </select>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label
              class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
            >
              {{ $t('KANBAN.MODAL.PRIORITY_LABEL') }}
            </label>
            <select
              v-model="form.priority"
              class="w-full h-10 px-3 border rounded-lg bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
            >
              <option value="low">
                {{ $t('KANBAN.CARD.PRIORITY_LOW') }}
              </option>
              <option value="medium">
                {{ $t('KANBAN.CARD.PRIORITY_MEDIUM') }}
              </option>
              <option value="high">
                {{ $t('KANBAN.CARD.PRIORITY_HIGH') }}
              </option>
              <option value="urgent">
                {{ $t('KANBAN.CARD.PRIORITY_URGENT') }}
              </option>
            </select>
          </div>

          <div>
            <label
              class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
            >
              {{ $t('KANBAN.MODAL.STATUS_LABEL') }}
            </label>
            <select
              v-model="form.status"
              class="w-full h-10 px-3 border rounded-lg bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
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

        <div>
          <label
            class="block mb-1 font-medium text-xs text-slate-600 dark:text-slate-300"
          >
            {{ $t('KANBAN.MODAL.DESCRIPTION_LABEL') }}
          </label>
          <textarea
            v-model="form.description"
            rows="3"
            :placeholder="$t('KANBAN.MODAL.DESCRIPTION_PLACEHOLDER')"
            class="w-full p-2.5 border rounded-lg bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
          />
        </div>

        <div v-if="card?.conversation">
          <div
            class="p-3 bg-slate-50 dark:bg-slate-800/60 rounded-lg border border-slate-200 dark:border-slate-700 flex items-center justify-between"
          >
            <div class="flex items-center gap-2">
              <span class="text-woot-500 text-lg">💬</span>
              <div>
                <p
                  class="text-xs font-semibold text-slate-700 dark:text-slate-200"
                >
                  {{ $t('KANBAN.MODAL.LINKED_CONVERSATION') }} #{{
                    card.conversation.display_id
                  }}
                </p>
                <p class="text-[11px] text-slate-500">
                  {{ card.contact?.name || 'Cliente' }}
                </p>
              </div>
            </div>
            <router-link
              :to="{
                name: 'inbox_conversation',
                params: { conversation_id: card.conversation.id },
              }"
              class="text-xs font-medium text-woot-600 hover:underline flex items-center gap-1"
              target="_blank"
            >
              {{ $t('KANBAN.MODAL.OPEN_CONVERSATION') }} ↗
            </router-link>
          </div>
        </div>

        <div
          v-if="form.id"
          class="pt-2 border-t border-slate-200 dark:border-slate-700 flex justify-between items-center"
        >
          <button
            type="button"
            class="text-xs text-red-600 hover:text-red-700 font-medium transition-colors"
            @click="handleDelete"
          >
            {{ $t('KANBAN.MODAL.DELETE_CARD') }}
          </button>
        </div>
      </div>

      <!-- Tab: Anotações -->
      <div v-show="activeTab === 'notes'" class="flex flex-col gap-3">
        <div class="flex flex-col gap-2">
          <textarea
            v-model="newNoteContent"
            rows="2"
            :placeholder="$t('KANBAN.MODAL.ADD_NOTE_PLACEHOLDER')"
            class="w-full p-2.5 border rounded-lg bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-sm focus:outline-none focus:ring-2 focus:ring-woot-500"
          />
          <div class="flex justify-end">
            <Button
              type="button"
              size="xs"
              :label="$t('KANBAN.MODAL.SAVE_NOTE_BUTTON')"
              :is-loading="isAddingNote"
              @click="handleAddNote"
            />
          </div>
        </div>

        <div class="flex flex-col gap-2 max-h-56 overflow-y-auto pr-1">
          <div
            v-for="note in notes"
            :key="note.id"
            class="p-2.5 bg-slate-50 dark:bg-slate-800/80 rounded-lg border border-slate-200 dark:border-slate-700 text-xs flex justify-between items-start gap-2"
          >
            <div>
              <p class="text-slate-800 dark:text-slate-100 whitespace-pre-wrap">
                {{ note.content }}
              </p>
              <p class="text-[10px] text-slate-400 mt-1">
                {{ note.user_name || 'Agente' }} •
                {{ new Date(note.created_at).toLocaleString() }}
              </p>
            </div>
            <button
              type="button"
              class="text-slate-400 hover:text-red-500 transition-colors"
              title="Excluir"
              @click="handleDeleteNote(note.id)"
            >
              ✕
            </button>
          </div>

          <p
            v-if="!notes.length"
            class="text-xs text-center py-4 text-slate-400"
          >
            {{ $t('KANBAN.MODAL.NO_NOTES') }}
          </p>
        </div>
      </div>
    </div>
  </Dialog>
</template>
