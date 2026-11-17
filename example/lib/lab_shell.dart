// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'lab_brand.dart';
import 'language_flags.dart';
import 'learning_pages.dart';
import 'learning_content.dart';
import 'workbench_page.dart';

class LabShell extends StatefulWidget {
  const LabShell(
      {super.key,
      required this.settings,
      required this.navigatorKey,
      required this.child,
      this.onOpenLink});
  final AppSettings settings;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final ValueChanged<String>? onOpenLink;
  @override
  State<LabShell> createState() => _LabShellState();
}

class _LabShellState extends State<LabShell> {
  int selected = 0;
  String tr(String en, String pt) => widget.settings.portuguese ? pt : en;
  void link(String url) {
    if (widget.onOpenLink != null) {
      widget.onOpenLink!(url);
      return;
    }
    if (!openExternal(url))
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: SelectableText(
              '${tr('Open this link in your browser', 'Abra este link no navegador')}: $url')));
  }

  void preset(LabPreset preset) {
    final launch = launchPreset(preset);
    setState(() => selected = 0);
    widget.navigatorKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => WorkbenchPage(
            portuguese: widget.settings.portuguese,
            initialModel: launch.model,
            initialInputs: launch.values)));
  }

  void navigate(int page) => setState(() => selected = page);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: SafeArea(
                bottom: false,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: LayoutBuilder(builder: (context, box) {
                    final wide = box.maxWidth >= 1100 &&
                        MediaQuery.textScalerOf(context).scale(1) < 1.25;
                    final labels = [
                      tr('Laboratory', 'Laboratório'),
                      tr('Learn', 'Aprender'),
                      tr('Examples', 'Exemplos')
                    ];
                    return SizedBox(
                        height: 72,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(children: [
                              Expanded(
                                  child: Semantics(
                                      label: tr(
                                          'Fuzzy Engine, return to laboratory',
                                          'Fuzzy Engine, voltar ao laboratório'),
                                      button: true,
                                      child: Tooltip(
                                          message: tr(
                                              'Return to your experiment',
                                              'Voltar ao seu experimento'),
                                          child: InkWell(
                                              key: const ValueKey('brand-home'),
                                              onTap: () => navigate(0),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Row(children: [
                                                const ExcludeSemantics(
                                                    child: FuzzyMark(size: 40)),
                                                if (box.maxWidth >= 365) ...[
                                                  const SizedBox(width: 10),
                                                  Flexible(
                                                      child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                        Text(
                                                            box.maxWidth < 600
                                                                ? 'Fuzzy'
                                                                : 'Fuzzy Engine',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .titleMedium),
                                                        if (wide)
                                                          Text(
                                                              'v$engineVersion · ${tr('explainable inference', 'inferência explicável')}',
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .labelSmall),
                                                      ]))
                                                ],
                                              ]))))),
                              if (wide) ...[
                                for (var i = 0; i < labels.length; i++)
                                  Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: TextButton(
                                          key: ValueKey([
                                            'nav-laboratory',
                                            'nav-learn',
                                            'nav-examples'
                                          ][i]),
                                          style: TextButton.styleFrom(
                                              backgroundColor: i == selected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer
                                                  : null),
                                          onPressed: () => navigate(i),
                                          child: Text(labels[i]))),
                                TextButton.icon(
                                    key: const ValueKey('nav-docs'),
                                    onPressed: () => link(
                                        guideUrl(widget.settings.portuguese)),
                                    icon:
                                        const Icon(Icons.open_in_new, size: 16),
                                    label: Text(
                                        tr('Documentation', 'Documentação'))),
                                TextButton(
                                    onPressed: () => link(repositoryUrl),
                                    child: const Text('GitHub')),
                                const SizedBox(width: 12),
                              ],
                              LanguageFlags(
                                  key: const ValueKey('language-selector'),
                                  settings: widget.settings),
                              IconButton(
                                  key: const ValueKey('toggle-theme'),
                                  tooltip: tr('Toggle light/dark theme',
                                      'Alternar tema claro/escuro'),
                                  onPressed: widget.settings.toggleTheme,
                                  icon: Icon(widget.settings.dark
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined)),
                              if (!wide)
                                PopupMenuButton<String>(
                                    key: const ValueKey('nav-menu'),
                                    tooltip: tr(
                                        'Navigation menu', 'Menu de navegação'),
                                    icon: const Icon(Icons.menu),
                                    onSelected: (value) {
                                      if (value == 'docs') {
                                        link(guideUrl(
                                            widget.settings.portuguese));
                                      } else if (value == 'github') {
                                        link(repositoryUrl);
                                      } else {
                                        navigate(int.parse(value));
                                      }
                                    },
                                    itemBuilder: (_) => [
                                          for (var i = 0;
                                              i < labels.length;
                                              i++)
                                            PopupMenuItem(
                                                value: '$i',
                                                child: Text(labels[i])),
                                          PopupMenuItem(
                                              value: 'docs',
                                              child: Text(tr('Documentation',
                                                  'Documentação'))),
                                          const PopupMenuItem(
                                              value: 'github',
                                              child: Text('GitHub')),
                                        ]),
                            ])));
                  }),
                ))),
        body: IndexedStack(index: selected, children: [
          widget.child,
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: LearnPage(onPreset: preset, onLink: link))),
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ExamplesPage(onPreset: preset))),
        ]),
      );
}
