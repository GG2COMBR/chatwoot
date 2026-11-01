import { frontendURL } from '../../../helper/URLHelper';
import KanbanIndex from './KanbanIndex.vue';
import BoardView from './BoardView.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    component: KanbanIndex,
    children: [
      {
        path: '',
        name: 'kanban_dashboard_index',
        component: BoardView,
      },
      {
        path: 'boards/:boardId',
        name: 'kanban_board_view',
        component: BoardView,
      },
    ],
  },
];
