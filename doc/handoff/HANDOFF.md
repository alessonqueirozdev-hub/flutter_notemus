# Handoff: flutter_notemus, do PC local para o Claude na nuvem

Escrito em 2026-11-23, quando o trabalho saiu do PC local do Alesson, que estava
sem espaço em disco, para sessões do Claude Code na nuvem (claude.ai/code). Tudo
o que existia só no PC está aqui ou no GitHub. **Leia inteiro antes de mexer em
qualquer coisa.**

## Regras de convivência

- **Responda sempre em português (pt-BR)**, inclusive a eventos automáticos de
  CI, Codex e Auto-fix. Código, identificadores, mensagens de commit e conteúdo
  de arquivos seguem a convenção do repositório, em inglês.
- **Nunca faça push direto no `master`.** Trabalhe em branch e abra PR. O merge
  só acontece quando o Alesson pede; a frase usual é "merge no verde", que vale
  só para o PR em questão.
- **Merge com merge commit, nunca squash.** O `.git-blame-ignore-revs` aponta
  para um SHA que precisa continuar existindo.
- **Não publique no pub.dev.** A publicação é feita pelo Alesson, com a conta
  dele.
- **Direção do projeto:** quando o código não faz o que a documentação diz,
  feche a lacuna no código; não rebaixe a documentação. Frase do Alesson: "Não
  quero corrigir os docs, eu quero que você trabalhe para nossa aplicação
  superar o que esta registrado! não devemos ter perdas."
- **Toda correção vem com um teste** que falha antes e passa depois. Veja o
  `CONTRIBUTING.md`.

## Estado em 2026-11-23

| Item | Estado |
|---|---|
| `master` | `9d65e14`, com #62, #63, #65, #66 e #67 |
| Última tag e GitHub Release | `v2.9.1` (correção do SwiftPM, #58) |
| **pub.dev** | **ainda 2.8.1.** 2.9.0, 2.9.1 e 2.10.0 nunca foram publicados |
| PR aberto do release | **#68 `release: 2.10.0`** (branch `release/2.10.0`) |
| Testes | 1166 passando com o #67 |

### O que estava em andamento

1. **Release 2.10.0 (PR #68).** A branch já inclui o #67 e o CHANGELOG está
   escrito. Faltam o CI verde, o merge (com merge commit) e depois a tag e o
   Release, que o Alesson pediu como "merge e tag" nos releases anteriores:
   ```bash
   git tag -a v2.10.0 -m "flutter_notemus 2.10.0" <sha-do-merge>
   git push origin v2.10.0
   # corpo do Release = a seção [2.10.0] do CHANGELOG, sem o título
   gh release create v2.10.0 --title "2.10.0 — <resumo>" --notes-file <arquivo> --latest
   ```
   **Confirme com o Alesson antes do merge.** Na última pergunta ("Faço o merge
   do #68 no verde e crio a tag v2.10.0?") ele ainda não tinha respondido.
2. **Publicação no pub.dev:** pendente, feita pelo Alesson com
   `flutter pub publish`. Depois dela, há uma promessa pública: comentar na
   issue #58 (axiopisty) que a versão está no pub.dev ("I'll post here once it's
   published").

### Colaboradores e conversas abertas

- **axiopisty**: abriu #58 (SwiftPM, corrigido no 2.9.1) e
  #61. Contribuiu o #62 (`displayCommonTimeSignatureGlyphs`) e aprovou o #65.
- **uveshm003**: contribuiu o #66 (símbolo do compasso nos
  importadores, fecha a #64) e o #67 (compasso livre e aditivo no JSON). Na
  aprovação do #67 sugerimos um acompanhamento: derivar o numerador dos grupos
  aditivos e avisar quando a soma não bater.
- **zamvar:** autor do fork portado em cinco partes (Discussion #50).
  Ofereceu-se para revisar e testar. Ainda não deu retorno.
- **ArtSilver:** contribuiu o #49 (beaming com fórmula herdada).
- **Sunketa** (fork): tem as branches `clavara/proportional-spacing` e
  `clavara/system-breaks`, com espaçamento proporcional e `measuresPerSystem`,
  sem PR. Partem de um master antigo (55 commits atrás), e a parte da barra
  final já foi corrigida no 2.9.0. Um convite para abrirem PR ainda não foi
  feito.
- **Issues abertas:** #1, #15, #16, #17, #20, #23, #24, #27–#33, #45, #46.
- **Dependabot:** #34–#41, parados.

## Decisões e armadilhas

- **Goldens só no Windows.** Os PNGs de `test/golden/goldens/` são gravados no
  Windows, e o CI os compara em `windows-latest`. **Na nuvem (Linux), não
  regrave goldens**: rode `--exclude-tags golden`. Para gravar ou atualizar um
  golden, é preciso uma máquina Windows. Foi o que fizemos no #62: o colaborador
  adicionou o caso, e nós gravamos o PNG no Windows e enviamos para a branch
  dele.
- **Formatação:** o job `Format` do CI é a referência. Rode `flutter pub get`
  (em `example/` e na raiz) antes do `dart format lib test example`. Sem pacote
  resolvido, o formatador usa o estilo mais novo e reescreve arquivos que já
  estão certos. Versões diferentes do Dart podem divergir em poucos trechos;
  vale o que o CI imprimir.
- **Flutter 3.47** deprecou `package:flutter/material.dart`. A biblioteca
  suporta `flutter >=3.0.0`, então **não migre para `material_ui`**. Os 9
  arquivos que precisam do Material mantêm o import com um `ignore` comentado;
  os demais usam `widgets.dart` (#63).
- **PRs de fork** precisam de aprovação para o CI rodar a cada push:
  `gh api -X POST repos/alessonqueirozdev-hub/flutter_notemus/actions/runs/<id>/approve`.
  O Auto-fix do app não acompanha PR de fork.
- **CI duplicado no master:** cada push gera duas execuções. Se os jobs de
  macOS forem cancelados numa delas, ela aparece como falha, mas não é defeito.
  Confira a execução gêmea.
- **Codex:** o revisor automático `chatgpt-codex-connector` está sem cota ("usage
  limits"). Os comentários dele sem achados não pedem ação.
- **ADR-005:** nada em `lib/src/layout/` ou `lib/src/rendering/` escreve em
  `Note.beam`, e as leituras de `Note.beam` passam por uma allow-list em
  `test/invariants/adr005_guard_test.dart`. Todo `TextStyle` passa por
  `withMusicTextFallback`, com allow-list em
  `test/invariants/text_painter_provenance_test.dart`.
- **`Duration`:** o pacote exporta um `Duration` musical. Nos testes, use
  `hide Duration` no import ou `MusicDuration`.
- **Follow-up conhecido:** a paginação do PDF
  (`ScoreRasterizer.renderGroupPages`) ainda corta na borda do bloco do sistema,
  e não no espaço entre sistemas, como já faz o `PagedScoreView`.

## Objetivo de longo prazo: canto gregoriano

O objetivo principal do Alesson é suporte gregoriano (neumas) de nível de
editor, para um app que edita e toca canto. Decisão de arquitetura: **renderizar
com a fonte Greciliae** (`assets/gregorian/`), com neumas pré-compostos. Bravura
e desenho por geometria foram rejeitados. Roteiro em `doc/GREGORIAN_PLAN.md` e
pesquisa em `doc/GREGORIAN_RESEARCH.json`. Prioridade declarada: fidelidade
máxima de renderização (initio debilis, pressus, oriscus isolado,
quilisma-scandicus e a ancoragem de altura pela clave) antes do playback.

## Como testar na nuvem

```bash
bash scripts/cloud-setup.sh          # instala o Flutter estável, resolve pacotes, roda um smoke test
source /etc/profile.d/flutter.sh
flutter test --exclude-tags golden   # a suíte lógica, como o CI roda no Linux
dart analyze lib test
(cd example && flutter analyze)
dart format lib test example && git diff --stat -- '*.dart'   # deve sair vazio
```

Se o download do Flutter ou dos artefatos (`storage.googleapis.com`) for
bloqueado pela allowlist de rede, avise o Alesson. O `pub.dev` está liberado.

## O que continua exigindo máquina local

- **Gravar ou atualizar goldens:** precisa de Windows.
- **`flutter pub publish`:** precisa da conta do Alesson.
- **Builds de macOS e iOS (SwiftPM):** o CI cobre no job `SwiftPM consumer
  build`. Localmente, só num Mac.
- **Rodar o app de exemplo num aparelho ou emulador.**
