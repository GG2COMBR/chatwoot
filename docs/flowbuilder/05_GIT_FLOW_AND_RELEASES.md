# 05. Git Flow, SemVer, Proteção de Branches e Mergeback

## 1. Topologia de Branches

No repositório oficial [`GG2COMBR/chatwoot`](https://github.com/GG2COMBR/chatwoot):

- **`main`**: Representa **Produção**. É protegida contra exclusão e force-push. Somente código aprovado em staging e tagueado entra aqui.
- **`staging`**: Representa **Homologação / Pré-Produção**. É a branch base onde todos os Pull Requests de features convergem.
- **Branches de Trabalho (`<tipo>/<id>`)**:
  - Exemplo: `feat/1`, `fix/42`, `docs/governance`.
  - Nascem sempre a partir de `staging`.
  - São abertas via PR exclusivamente apontando para `staging`.
  - São deletadas automaticamente no merge (`delete_branch_on_merge: true`).

---

## 2. Regras de Proteção e Políticas de Merge

- **Sem Squash Merge**: `allow_squash_merge: false`. O histórico é preservado via Merge Commit ou Rebase Merge.
- **Proteção de Branch**: Force-push e exclusão bloqueados em `main` e `staging`.
- **Validação de CI**: RSpec e lint devem estar verdes antes da aprovação.

---

## 3. O Ciclo de Promoção (`staging` ➔ `main`)

1. Ao concluir uma Milestone ou pacote de entregas em `staging`:
2. O Tech Lead abre um PR de Release:
   - Base: `main` | Head: `staging`.
   - Título: `release: vX.Y.Z - <Milestone>`.
3. Merge executado via Merge Commit na `main`.
4. Criação da Tag SemVer e GitHub Release:
   ```bash
   gh release create vX.Y.Z --target main --generate-notes
   ```
5. Fechamento da Milestone no GitHub API.

---

## 4. O Protocolo Crítico de Mergeback (`main` ➔ `staging`)

Para evitar divergência de histórico (Git Drift) e garantir que tags, commits de release e eventuais hotfixes de produção nunca se percam:

1. **Imediatamente após o merge em `main`**:
   - Dispara-se o mergeback trazendo os commits de `main` de volta para `staging`.
2. **Automação via GitHub Action (`.github/workflows/mergeback.yml`)**:
   - Executa automaticamente o merge `main` ➔ `staging` com commit de sincronização `chore(git): mergeback main into staging [skip ci]`.
3. **Hotfix Emergencial**:
   - Se ocorrer um bug crítico em produção, cria-se `hotfix/<id>` a partir de `main`.
   - Mergeia-se em `main` com tag de patch (`vX.Y.Z+1`).
   - O mergeback propaga o hotfix imediatamente para `staging`.
