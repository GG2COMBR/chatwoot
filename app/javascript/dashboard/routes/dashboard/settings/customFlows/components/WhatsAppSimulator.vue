<script setup>
import { ref, computed, watch } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineOptions({
  name: 'WhatsAppSimulator',
});

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false,
  },
  nodes: {
    type: Array,
    default: () => [],
  },
  edges: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close']);

const messages = ref([]);
const currentNodeId = ref(null);
const userInput = ref('');
const isSimulating = ref(false);

const startNode = computed(() => {
  return props.nodes.find(n => n.type === 'start' || n.id === 'start') || props.nodes[0];
});

const resetSimulation = () => {
  messages.value = [];
  userInput.value = '';
  if (!startNode.value) return;

  currentNodeId.value = startNode.value.id;
  processNode(startNode.value);
};

watch(
  () => props.isOpen,
  open => {
    if (open) {
      resetSimulation();
    }
  }
);

const getNextNodes = fromNodeId => {
  const outgoingEdges = props.edges.filter(e => e.source === fromNodeId);
  return outgoingEdges
    .map(e => props.nodes.find(n => n.id === e.target))
    .filter(Boolean);
};

const processNode = node => {
  if (!node) return;
  isSimulating.value = true;

  setTimeout(() => {
    switch (node.type) {
      case 'start': {
        const text = node.data?.text || 'Olá! Bem-vindo ao atendimento automatizado.';
        addBotMessage(text);
        advanceToNext(node.id);
        break;
      }
      case 'message': {
        addBotMessage(node.data?.text || 'Mensagem do atendente');
        advanceToNext(node.id);
        break;
      }
      case 'interactive_buttons': {
        addBotInteractiveMessage(node.data?.body || 'Escolha uma opção:', node.data?.buttons || []);
        isSimulating.value = false;
        break;
      }
      case 'interactive_list': {
        addBotMessage(`${node.data?.body || 'Selecione uma opção da lista'}`);
        isSimulating.value = false;
        break;
      }
      case 'business_hours': {
        addSystemNotice('⏰ Horário de Atendimento: Expediente Aberto');
        advanceToNext(node.id);
        break;
      }
      case 'ai_fallback':
      case 'ai_agent': {
        addBotMessage('🤖 [IA Bedrock] Olá! Sou a assistente inteligente da GG2. Como posso ajudar com seu pedido?');
        isSimulating.value = false;
        break;
      }
      case 'human_transfer': {
        addSystemNotice('👤 Conversa transferida para a equipe de atendimento humano');
        addBotMessage(node.data?.transfer_message || 'Um momento, transferindo seu contato...');
        isSimulating.value = false;
        break;
      }
      case 'kanban_stage_change': {
        const stageName = node.data?.stage_name || node.data?.stage_id || 'Estágio';
        addSystemNotice(`📊 Cartão movido no Kanban para: "${stageName}"`);
        advanceToNext(node.id);
        break;
      }
      case 'async_api': {
        addBotMessage(node.data?.wait_message || '⏳ Aguarde um instante enquanto consultamos nossos sistemas...');
        setTimeout(() => {
          addBotMessage('✅ Dados localizados com sucesso no sistema!');
          advanceToNext(node.id);
        }, 800);
        break;
      }
      case 'finish': {
        addBotMessage(node.data?.farewell_message || 'Atendimento encerrado. Obrigado!');
        addSystemNotice('⭐ Pesquisa de Satisfação (CSAT) enviada ao cliente');
        addSystemNotice('🏁 Sessão finalizada');
        isSimulating.value = false;
        break;
      }
      default: {
        advanceToNext(node.id);
        break;
      }
    }
  }, 400);
};

const advanceToNext = fromNodeId => {
  const nextNodes = getNextNodes(fromNodeId);
  if (nextNodes.length > 0) {
    const nextNode = nextNodes[0];
    currentNodeId.value = nextNode.id;
    processNode(nextNode);
  } else {
    isSimulating.value = false;
  }
};

const addBotMessage = text => {
  messages.value.push({
    id: `m_${Date.now()}_${Math.random()}`,
    sender: 'bot',
    text,
    time: formatTime(),
  });
};

const addBotInteractiveMessage = (text, buttons) => {
  messages.value.push({
    id: `m_${Date.now()}_${Math.random()}`,
    sender: 'bot',
    text,
    buttons,
    time: formatTime(),
  });
};

const addUserMessage = text => {
  messages.value.push({
    id: `m_${Date.now()}_${Math.random()}`,
    sender: 'user',
    text,
    time: formatTime(),
  });
};

const addSystemNotice = text => {
  messages.value.push({
    id: `m_${Date.now()}_${Math.random()}`,
    sender: 'system',
    text,
    time: formatTime(),
  });
};

const handleButtonClick = (button, parentMessage) => {
  addUserMessage(button.title);
  parentMessage.selectedButtonId = button.id;

  const nextNodes = getNextNodes(currentNodeId.value);
  if (nextNodes.length > 0) {
    const nextNode = nextNodes[0];
    currentNodeId.value = nextNode.id;
    processNode(nextNode);
  }
};

const handleSendInput = () => {
  const text = userInput.value.trim();
  if (!text) return;

  addUserMessage(text);
  userInput.value = '';

  const nextNodes = getNextNodes(currentNodeId.value);
  if (nextNodes.length > 0) {
    const nextNode = nextNodes[0];
    currentNodeId.value = nextNode.id;
    processNode(nextNode);
  } else {
    setTimeout(() => {
      addBotMessage('Entendido! Processando sua solicitação...');
    }, 400);
  }
};

const formatTime = () => {
  const now = new Date();
  return now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
};
</script>

<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 select-none"
  >
    <div class="w-full max-w-sm h-[680px] bg-slate-900 rounded-[36px] p-3 shadow-2xl border-4 border-slate-700 flex flex-col relative overflow-hidden">
      <!-- Notch do Smartphone -->
      <div class="absolute top-4 left-1/2 -translate-x-1/2 w-28 h-4 bg-slate-800 rounded-full z-20 flex items-center justify-center">
        <div class="size-2 rounded-full bg-slate-950/80 mr-3" />
        <div class="w-8 h-1 rounded-full bg-slate-700/40" />
      </div>

      <!-- Moldura Interna do WhatsApp -->
      <div class="flex-1 w-full bg-[#0b141a] rounded-[28px] overflow-hidden flex flex-col relative">
        <!-- Topbar WhatsApp -->
        <div class="bg-[#202c33] px-3 pt-6 pb-2.5 flex items-center justify-between text-white border-b border-[#2a3942] shrink-0">
          <div class="flex items-center gap-2.5">
            <div class="size-9 rounded-full bg-emerald-600 flex items-center justify-center font-bold text-xs">
              GG2
            </div>
            <div class="flex flex-col">
              <span class="text-xs font-semibold leading-tight">GG2 Atendimento</span>
              <span class="text-[10px] text-emerald-400">online</span>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <button
              type="button"
              class="p-1 hover:bg-white/10 rounded-full text-slate-300 transition-colors"
              title="Reiniciar Simulação"
              @click="resetSimulation"
            >
              <Icon icon="i-lucide-rotate-ccw" class="size-4" />
            </button>
            <button
              type="button"
              class="p-1 hover:bg-white/10 rounded-full text-slate-300 transition-colors"
              title="Fechar"
              @click="emit('close')"
            >
              <Icon icon="i-lucide-x" class="size-4" />
            </button>
          </div>
        </div>

        <!-- Área de Mensagens (Chat Wallpaper) -->
        <div class="flex-1 p-3 overflow-y-auto flex flex-col gap-2.5 bg-[#0b141a]">
          <!-- Aviso Criptografia Meta -->
          <div class="self-center bg-[#182229] border border-[#222e35] px-2.5 py-1 rounded-md text-[10px] text-amber-200/80 text-center max-w-[260px] my-1">
            🔒 As mensagens são protegidas com a criptografia de ponta a ponta.
          </div>

          <div
            v-for="msg in messages"
            :key="msg.id"
            class="flex flex-col"
          >
            <!-- Mensagem de Sistema / Status -->
            <div
              v-if="msg.sender === 'system'"
              class="self-center bg-[#182229] border border-[#2a3942] text-[10px] text-slate-300 px-3 py-1 rounded-full my-1 max-w-[260px] text-center"
            >
              {{ msg.text }}
            </div>

            <!-- Balão do Bot (Incoming) -->
            <div
              v-else-if="msg.sender === 'bot'"
              class="self-start max-w-[85%] bg-[#202c33] text-slate-100 rounded-lg rounded-tl-none p-2.5 shadow-sm text-xs relative flex flex-col gap-1.5 border border-[#2a3942]/60"
            >
              <p class="whitespace-pre-line leading-relaxed">{{ msg.text }}</p>

              <!-- Botões Interativos -->
              <div v-if="msg.buttons?.length" class="flex flex-col gap-1 pt-1 border-t border-[#2a3942]">
                <button
                  v-for="btn in msg.buttons"
                  :key="btn.id"
                  type="button"
                  class="w-full py-1.5 px-3 rounded text-center text-xs font-medium text-emerald-400 bg-[#111b21] hover:bg-emerald-600 hover:text-white transition-colors border border-[#2a3942]"
                  :disabled="isSimulating"
                  @click="handleButtonClick(btn, msg)"
                >
                  {{ btn.title }}
                </button>
              </div>

              <span class="text-[9px] text-slate-400 self-end mt-0.5">{{ msg.time }}</span>
            </div>

            <!-- Balão do Usuário (Outgoing) -->
            <div
              v-else-if="msg.sender === 'user'"
              class="self-end max-w-[85%] bg-[#005c4b] text-slate-100 rounded-lg rounded-tr-none p-2.5 shadow-sm text-xs relative flex flex-col gap-0.5"
            >
              <p class="whitespace-pre-line leading-relaxed">{{ msg.text }}</p>
              <div class="flex items-center gap-1 self-end">
                <span class="text-[9px] text-emerald-200/70">{{ msg.time }}</span>
                <Icon icon="i-lucide-check-check" class="size-3 text-cyan-300" />
              </div>
            </div>
          </div>
        </div>

        <!-- Barra Inferior de Entrada (Input Bar) -->
        <div class="bg-[#202c33] p-2 flex items-center gap-2 border-t border-[#2a3942] shrink-0">
          <input
            v-model="userInput"
            type="text"
            placeholder="Mensagem..."
            class="flex-1 bg-[#2a3942] text-xs text-slate-100 placeholder-slate-400 rounded-full px-3.5 py-2 outline-none"
            :disabled="isSimulating"
            @keyup.enter="handleSendInput"
          />
          <button
            type="button"
            class="size-8 rounded-full bg-emerald-600 hover:bg-emerald-500 text-white flex items-center justify-center shrink-0 transition-colors disabled:opacity-50"
            :disabled="!userInput.trim() || isSimulating"
            @click="handleSendInput"
          >
            <Icon icon="i-lucide-send" class="size-3.5" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
