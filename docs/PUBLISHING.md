# Release checklist / Checklist de publicação

Current state: development source, not a published release.
Estado atual: código em desenvolvimento, ainda não publicado.

1. Confirm the package name is available on pub.dev; `fuzzy_engine` is provisional.
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
