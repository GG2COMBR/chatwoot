<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

export default {
  name: 'AddCanned',
  components: {
    NextButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    responseContent: {
      type: String,
      default: '',
    },
    onClose: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      shortCode: '',
      content: this.responseContent || '',
      visibilityType: 'public',
      selectedTeamIds: [],
      addCanned: {
        showLoading: false,
        message: '',
      },
      show: true,
    };
  },
  computed: {
    teams() {
      return this.$store.getters['teams/getTeams'] || [];
    },
  },
  mounted() {
    this.$store.dispatch('teams/get');
  },
  validations: {
    shortCode: {
      required,
      minLength: minLength(2),
    },
    content: {
      required,
    },
  },
  methods: {
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.visibilityType = 'public';
      this.selectedTeamIds = [];
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    addCannedResponse() {
      // Show loading on button
      this.addCanned.showLoading = true;
      // Make API Calls
      this.$store
        .dispatch('createCannedResponse', {
          short_code: this.shortCode,
          content: this.content,
          team_ids:
            this.visibilityType === 'restricted' ? this.selectedTeamIds : [],
        })
        .then(() => {
          // Reset Form, Show success message
          this.addCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.ADD.API.SUCCESS_MESSAGE'));
          this.resetForm();
          this.onClose();
        })
        .catch(error => {
          this.addCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CANNED_MGMT.ADD.TITLE')"
        :header-content="$t('CANNED_MGMT.ADD.DESC')"
      />
      <form class="flex flex-col w-full" @submit.prevent="addCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.PLACEHOLDER')"
              @blur="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.content.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: v$.content.$error }"
              channel-type="Context::Default"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
            />
          </div>
        </div>

        <div class="w-full my-3">
          <label class="text-sm font-medium text-n-slate-12 block mb-1">
            {{ $t('CANNED_MGMT.ADD.FORM.VISIBILITY.LABEL') }}
          </label>
          <div class="flex items-center gap-6 my-2 text-sm">
            <label
              class="flex items-center gap-2 cursor-pointer text-n-slate-12"
            >
              <input
                v-model="visibilityType"
                type="radio"
                value="public"
                class="text-woot-500 focus:ring-woot-500"
              />
              {{ $t('CANNED_MGMT.ADD.FORM.VISIBILITY.PUBLIC') }}
            </label>
            <label
              class="flex items-center gap-2 cursor-pointer text-n-slate-12"
            >
              <input
                v-model="visibilityType"
                type="radio"
                value="restricted"
                class="text-woot-500 focus:ring-woot-500"
              />
              {{ $t('CANNED_MGMT.ADD.FORM.VISIBILITY.RESTRICTED') }}
            </label>
          </div>

          <div
            v-if="visibilityType === 'restricted'"
            class="mt-2 p-3 bg-n-alpha-1 rounded-lg border border-n-strong"
          >
            <label
              class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider block mb-2"
            >
              {{ $t('CANNED_MGMT.ADD.FORM.VISIBILITY.TEAMS_LABEL') }}
            </label>
            <div
              v-if="teams.length === 0"
              class="text-sm text-n-slate-11 italic"
            >
              {{ $t('CANNED_MGMT.ADD.FORM.VISIBILITY.NO_TEAMS') }}
            </div>
            <div v-else class="grid grid-cols-2 gap-2 max-h-40 overflow-y-auto">
              <label
                v-for="team in teams"
                :key="team.id"
                class="flex items-center gap-2 text-sm text-n-slate-12 cursor-pointer p-1.5 rounded hover:bg-n-alpha-2"
              >
                <input
                  v-model="selectedTeamIds"
                  type="checkbox"
                  :value="team.id"
                  class="rounded text-woot-500 focus:ring-woot-500"
                />
                <span class="truncate">{{ team.name }}</span>
              </label>
            </div>
          </div>
        </div>
        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.ADD.FORM.SUBMIT')"
            :disabled="
              v$.content.$invalid ||
              v$.shortCode.$invalid ||
              addCanned.showLoading
            "
            :is-loading="addCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
:deep(.ProseMirror-menubar) {
  @apply hidden;
}

:deep(.ProseMirror-woot-style) {
  @apply min-h-[12.5rem];
}
</style>
