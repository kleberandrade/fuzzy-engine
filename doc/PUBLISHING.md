# Releases / Publicações

Version 0.1.0 was published on 2026-11-16 and confirmed through the public Pub API.
A versão 0.1.0 foi publicada em 16/11/2026 e confirmada pela API pública do Pub.

## One-time activation / Ativação única

Automated GitHub OIDC publishing is enabled and successfully published 0.2.0 on
2026-11-16. The package belongs to `kleberandrade.dev`. To configure it again, use [package administration](https://pub.dev/packages/fuzzy_engine/admin):

- Enable publishing from GitHub Actions.
- Repository: `kleberandrade/fuzzy-engine`.
- Tag pattern: `v{{version}}`.

A publicação OIDC está ativa e publicou a versão 0.2.0 em 16/11/2026. O pacote
pertence a `kleberandrade.dev`. Para reconfigurar, use os valores acima em
Automated publishing no painel do pacote.
Essa autorização permite publicar a partir das tags desse repositório. Não é
necessário criar/copiar tokens ou chaves persistentes. A sessão do navegador não
substitui essa configuração. Sem ela, o job falhará na autenticação.

## Release flow / Fluxo de release

Add user-facing notes under `## Unreleased`, then prepare the version:
Adicione as mudanças em `## Unreleased` e prepare a versão:

```sh
dart run tool/bump_version.dart patch
# or minor / major, according to the change
```

The command updates pubspec.yaml and moves pending notes into the new changelog
section. It does not commit, tag, push or publish. Patch fixes compatible behavior;
minor adds features. During 0.x, document breaking changes and increment minor.
After 1.0, breaking changes require major. Bump once per release, not per commit.
A documentation/automation commit alone need not create a new package release.

O comando atualiza versão e changelog juntos, sem alterar o Git nem publicar.
Use patch para correções compatíveis e minor para novos recursos. Em 0.x, mudanças
incompatíveis precisam ser documentadas e incrementar minor; após 1.0, use major.
Faça um bump por release, sem publicar uma nova versão a cada commit de documentação.

Review changes and run the release checks before committing. For a prepared
0.3.0 release, for example:

```sh
bash tool/check_release.sh
git add pubspec.yaml CHANGELOG.md
git commit -m "chore(release): prepare 0.3.0"
git push origin main
git tag v0.3.0
git push origin v0.3.0
```

Use the actual prepared version. Do not push a 0.1.0 tag to test this automation;
that version is already published. The tag workflow verifies that tag, pubspec
and changelog match, then runs the full reusable CI (minimum/stable Dart, release
tool tests, Flutter analysis/tests/web build, external comparisons and dry-run).
Only after success does the publish job acquire temporary OIDC credentials,
repeat the dry-run and upload using `flutter pub publish --force`. Here `--force`
removes the interactive prompt; validation and warnings remain enforced.

Use a versão realmente preparada. A tag precisa corresponder à versão e ao
changelog. O CI completo bloqueia a publicação em caso de falha. Somente o job de
envio recebe permissão OIDC; nenhum segredo é salvo no código. Não use
`--skip-validation` ou `--ignore-warnings` para contornar falhas.

Confirm each new version at https://pub.dev/packages/fuzzy_engine and inspect the
[workflow runs](https://github.com/kleberandrade/fuzzy-engine/actions).
A workflow committed locally is not evidence of a completed remote publication.
Confirme cada versão na página pública e no resultado do workflow remoto.

Official reference: https://dart.dev/tools/pub/automated-publishing
