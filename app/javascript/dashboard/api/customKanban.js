/* global axios */
import ApiClient from './ApiClient';

class CustomKanbanAPI extends ApiClient {
  constructor() {
    super('kanban_boards', { accountScoped: true });
  }

  getBoards() {
    return this.get();
  }

  getBoard(boardId) {
    return this.show(boardId);
  }

  createBoard(data) {
    return this.create(data);
  }

  updateBoard(boardId, data) {
    return this.update(boardId, data);
  }

  deleteBoard(boardId) {
    return this.delete(boardId);
  }

  getStages(boardId) {
    return axios.get(`${this.url}/${boardId}/stages`);
  }

  createStage(boardId, data) {
    return axios.post(`${this.url}/${boardId}/stages`, { stage: data });
  }

  updateStage(boardId, stageId, data) {
    return axios.patch(`${this.url}/${boardId}/stages/${stageId}`, {
      stage: data,
    });
  }

  deleteStage(boardId, stageId) {
    return axios.delete(`${this.url}/${boardId}/stages/${stageId}`);
  }

  reorderStages(boardId, stageIds) {
    return axios.post(`${this.url}/${boardId}/stages/reorder`, {
      stage_ids: stageIds,
    });
  }

  getCards(boardId, params = {}) {
    return axios.get(`${this.url}/${boardId}/cards`, { params });
  }

  createCard(boardId, cardData) {
    return axios.post(`${this.url}/${boardId}/cards`, { card: cardData });
  }

  getCard(cardId) {
    return axios.get(`${this.baseUrl()}/kanban_cards/${cardId}`);
  }

  updateCard(cardId, cardData) {
    return axios.patch(`${this.baseUrl()}/kanban_cards/${cardId}`, {
      card: cardData,
    });
  }

  moveCard(cardId, { stageId, position }) {
    return axios.post(`${this.baseUrl()}/kanban_cards/${cardId}/move`, {
      stage_id: stageId,
      position,
    });
  }

  deleteCard(cardId) {
    return axios.delete(`${this.baseUrl()}/kanban_cards/${cardId}`);
  }

  getNotes(cardId) {
    return axios.get(`${this.baseUrl()}/kanban_cards/${cardId}/notes`);
  }

  createNote(cardId, content) {
    return axios.post(`${this.baseUrl()}/kanban_cards/${cardId}/notes`, {
      note: { content },
    });
  }

  deleteNote(cardId, noteId) {
    return axios.delete(
      `${this.baseUrl()}/kanban_cards/${cardId}/notes/${noteId}`
    );
  }

  getReasons(boardId) {
    return axios.get(`${this.url}/${boardId}/reasons`);
  }

  createReason(boardId, data) {
    return axios.post(`${this.url}/${boardId}/reasons`, { reason: data });
  }

  deleteReason(boardId, reasonId) {
    return axios.delete(`${this.url}/${boardId}/reasons/${reasonId}`);
  }
}

export default new CustomKanbanAPI();
