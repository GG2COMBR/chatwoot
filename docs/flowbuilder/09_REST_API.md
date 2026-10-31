# 09. Endpoints REST da API do Flowbuilder

## 1. Visão Geral

O Flowbuilder disponibiliza uma API REST completa para que o frontend administrativo (Vue Flow) gerencie os fluxos conversacionais da conta. Todos os endpoints exigem autenticação de administrador da conta.

- **Base URL**: `/api/v1/accounts/:account_id/custom_flows`
- **Autenticação**: Headers Devise Token Auth (`access-token`, `client`, `uid`) ou API Token de Administrador.

---

## 2. Endpoints Disponíveis

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/api/v1/accounts/:account_id/custom_flows` | Lista todos os fluxos da conta (filtros por `status` e `query`) |
| `POST` | `/api/v1/accounts/:account_id/custom_flows` | Cria um novo fluxo no status `draft` (Rascunho) |
| `GET` | `/api/v1/accounts/:account_id/custom_flows/:id` | Retorna o grafo completo (nós, conexões e gatilhos) |
| `PATCH` | `/api/v1/accounts/:account_id/custom_flows/:id` | Atualiza nós, conexões, nome ou trigger do fluxo |
| `POST` | `/api/v1/accounts/:account_id/custom_flows/:id/publish` | Valida integridade do grafo e publica (`published`) |
| `POST` | `/api/v1/accounts/:account_id/custom_flows/:id/duplicate` | Cria uma cópia independente do fluxo em rascunho |
| `DELETE` | `/api/v1/accounts/:account_id/custom_flows/:id` | Remove o fluxo da conta |

---

## 3. Exemplo de Payload do Grafo (`nodes` e `edges`)

```json
{
  "custom_flow": {
    "name": "Atendimento Comercial URA",
    "description": "Qualificação de leads e roteamento por equipe",
    "trigger_type": "default",
    "trigger_config": {},
    "nodes": [
      {
        "id": "start",
        "type": "start",
        "position": { "x": 100, "y": 100 },
        "data": {}
      },
      {
        "id": "menu_principal",
        "type": "interactive_buttons",
        "position": { "x": 100, "y": 250 },
        "data": {
          "header": "Bem-vindo à GG2!",
          "body": "Escolha como podemos te ajudar hoje:",
          "buttons": [
            { "id": "btn_vendas", "title": "Comprar Produtos" },
            { "id": "btn_suporte", "title": "Dúvidas e SAC" }
          ]
        }
      }
    ],
    "edges": [
      {
        "id": "edge_start_menu",
        "source": "start",
        "target": "menu_principal"
      }
    ]
  }
}
```

---

## 4. Regras de Validação para Publicação (`POST /publish`)

1. O fluxo não pode estar vazio (`nodes` deve ter pelo menos 1 elemento).
2. O grafo deve conter obrigatoriamente um nó de início (`type == 'start'` ou `id == 'start'`).
3. Resposta em caso de sucesso: `200 OK` com `status: "published"`.
4. Resposta em caso de erro de integridade: `422 Unprocessable Content` com mensagem explicativa em português claro.
