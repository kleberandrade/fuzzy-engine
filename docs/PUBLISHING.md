# Release checklist / Checklist de publicação

Current state: development source, not a published release.
Estado atual: código em desenvolvimento, ainda não publicado.

## Names and publication / Nomes e publicação

The GitHub repository is `fuzzy-engine`; the Dart package and import are
`fuzzy_engine` and `package:fuzzy_engine/fuzzy_engine.dart`. Dart package names
use lowercase letters and underscores, so the repository does not need renaming.

O repositório no GitHub é `fuzzy-engine`; o pacote Dart é `fuzzy_engine`, com
import `package:fuzzy_engine/fuzzy_engine.dart`. O nome do pacote usa letras
minúsculas e underscore. Não é necessário renomear o repositório.

GitHub pushes, commits and release tags do not upload this package to pub.dev.
The current CI runs `flutter pub publish --dry-run` only: this checks the upload
without creating a package page. There is no automatic publishing workflow.

Push, commit e tag no GitHub não publicam este pacote no pub.dev. O CI atual
executa somente `flutter pub publish --dry-run`, que valida o envio sem publicar.
Não há publicação automática configurada.

## Validation and first upload / Validação e primeiro envio

From the repository root, with Dart and Flutter on PATH and network access:
Na raiz do repositório, com Dart e Flutter no PATH e acesso à rede:

```sh
bash tool/check_release.sh
```

The script stops at the first failure and never publishes. Check the remote CI
matrix too; a local run does not test every supported SDK. Resolve all warnings,
review the dry-run file list, and consolidate the unreleased changelog into the
version selected for the first upload before proceeding.

O script para na primeira falha e nunca publica. Confira também a matriz do CI,
resolva os avisos, revise os arquivos do dry-run e consolide o changelog pendente
na versão escolhida para o primeiro envio. A execução local não cobre todos os SDKs.

Then, from the root, run the actual upload and complete the pub.dev authentication
if requested. Use the intended account; do not commit authentication tokens.
Em seguida, na raiz, execute o envio real e conclua a autenticação solicitada com
a conta desejada. Não adicione tokens ao repositório.

```sh
flutter pub publish
```

After successful upload, confirm the version at
https://pub.dev/packages/fuzzy_engine and test installation from a separate
project with `dart pub add fuzzy_engine` (or `flutter pub add fuzzy_engine`).
A URL returns 404 before a package page exists; that alone does not guarantee
the name can be registered. The server validates availability during publication.

Após o envio confirmado, verifique a versão na página do pacote e teste a
instalação em outro projeto. Um 404 não garante a disponibilidade do nome;
o servidor faz essa validação na publicação.

## Checklist

1. Confirm the package name is available on pub.dev before the first upload.
   Confirme a disponibilidade do nome antes da primeira publicação.
2. Review the MIT license, copyright and public source repository.
   Revise a licença e o repositório público.
3. Verify the `repository` and `issue_tracker` URLs in pubspec.yaml.
   Confirme os links do repositório e das issues.
4. Review both READMEs, version, changelog, exported API and generated docs.
   Revise documentação, versão, changelog e interface pública.
5. Run the commands below and resolve warnings. Test Flutter in a supported browser.
   Execute os comandos abaixo e valide o exemplo em um navegador.
6. Check the dry-run file list for generated files and unintended data.
   Revise os arquivos incluídos no pacote.
7. Use the intended pub.dev account/publisher and publish deliberately.
   Publique com a conta/publisher desejada. Publishing is a separate release step.

```sh
dart pub get --no-example
dart format --output=none --set-exit-if-changed lib test example
dart analyze --fatal-infos
dart test
dart doc
flutter pub publish --dry-run
cd example
flutter pub get
flutter analyze
flutter create --platforms=web .
flutter build web
# From the package root after all release checks:
# flutter pub publish
```

Official references / Referências oficiais:
- https://dart.dev/tools/pub/publishing
- https://dart.dev/tools/pub/create-packages
- https://dart.dev/tools/pub/cmd/pub-lish
