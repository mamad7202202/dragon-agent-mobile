import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/presets.dart';
import '../../core/theme.dart';
import '../../data/llm.dart';
import '../../state/app_state.dart';
import '../widgets/dragon_mark.dart';

/// First-run setup wizard: provider → connection → model.
class SetupWizard extends StatefulWidget {
  final bool editMode;
  const SetupWizard({super.key, this.editMode = false});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  var _step = 0;

  Preset? _preset;
  late final _url = TextEditingController();
  late final _key = TextEditingController();
  var _showKey = false;
  String? _suggestedModel;
  final _customModel = TextEditingController();

  String get chosenModel {
    final custom = _customModel.text.trim();
    return custom.isNotEmpty ? custom : (_suggestedModel ?? '');
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _customModel.dispose();
    super.dispose();
  }

  bool get _canNext {
    switch (_step) {
      case 0:
        return _preset != null;
      case 1:
        if (_preset!.name == 'custom') return _url.text.trim().startsWith('http');
        return true;
      case 2:
        return chosenModel.isNotEmpty;
    }
    return false;
  }

  Future<void> _finish() async {
    final model = chosenModel;
    final preset = _preset!;
    final state = context.read<AppState>();
    await state.saveProvider(ProviderCfg(
      name: preset.name,
      baseUrl: _url.text.trim(),
      protocol: preset.protocol,
      apiKey: _key.text.trim(),
      models: [model],
    ));
    await state.setActiveModel(model);
    if (!mounted) return;
    if (widget.editMode) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-1.2, -1.4),
            radius: 1.6,
            colors: [Color(0xFF2A160E), DragonColors.bg],
            stops: [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                child: Row(
                  children: [
                    const DragonMonogram(size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dragon Agent',
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(_titles[_step],
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    if (widget.editMode)
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              // progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: List.generate(3, (i) {
                    final active = i <= _step;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        margin: EdgeInsets.only(right: i == 2 ? 0 : 8),
                        decoration: BoxDecoration(
                          color: active ? null : DragonColors.stroke,
                          borderRadius: BorderRadius.circular(4),
                          gradient: active ? DragonColors.emberGradient : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: switch (_step) {
                      0 => _pickProvider(),
                      1 => _connection(),
                      _ => _modelStep(),
                    },
                  ),
                ),
              ),
              // footer nav
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                          onPressed: () => setState(() => _step--),
                          child: const Text('Back')),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: DragonColors.ember,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(130, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17)),
                      ),
                      onPressed: !_canNext
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              if (_step < 2) {
                                setState(() => _step++);
                              } else {
                                _finish();
                              }
                            },
                      icon: Icon(_step == 2
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded),
                      label: Text(_step == 2 ? 'Start' : 'Continue'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _titles = ['Choose a provider', 'Connect', 'Pick a model'];

  // ---------------- step 1 ----------------

  Widget _pickProvider() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemCount: presets.length,
      itemBuilder: (context, i) {
        final p = presets[i];
        final selected = _preset?.name == p.name;
        return Material(
          color: selected
              ? DragonColors.ember.withValues(alpha: 0.13)
              : Theme.of(context).brightness == Brightness.dark
                  ? DragonColors.card
                  : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _preset = p;
                _url.text = p.baseUrl;
                _suggestedModel = p.models.isEmpty ? null : p.models.first;
                _customModel.clear();
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Color(p.colorSeed).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(p.glyph,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(p.colorSeed))),
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(Icons.check_circle_rounded,
                            size: 19, color: DragonColors.gold),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(p.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
                  const SizedBox(height: 3),
                  Text(p.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, height: 1.3, color: DragonColors.textDim)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------- step 2 ----------------

  Widget _connection() {
    final p = _preset;
    if (p == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      children: [
        Text(p.note, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 18),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enabled: p.name == 'custom' || p.baseUrl.contains('localhost'),
          decoration: InputDecoration(
            labelText: 'Base URL',
            hintText: 'https://api.example.com/v1',
            helperText: p.baseUrl.contains('localhost')
                ? 'Replace with your PC LAN IP to reach local models'
                : null,
            prefixIcon: Icon(Icons.link_rounded, color: DragonColors.textDim, size: 20),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _key,
          obscureText: !_showKey,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: p.keyRequired ? 'API key *' : 'API key (optional)',
            hintText: 'sk-…',
            prefixIcon:
                Icon(Icons.vpn_key_rounded, color: DragonColors.textDim, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20, color: DragonColors.textDim),
              onPressed: () => setState(() => _showKey = !_showKey),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: DragonColors.ember.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DragonColors.ember.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 17, color: DragonColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your key is stored only on this device and sent directly '
                  'to the provider. No middleman servers.',
                  style: TextStyle(fontSize: 11.5, height: 1.5, color: DragonColors.textDim),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- step 3 ----------------

  Widget _modelStep() {
    final p = _preset;
    if (p == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      children: [
        Text('Suggested for ${p.label}:',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in p.models)
              ChoiceChip(
                label: Text(m),
                selected:
                    _suggestedModel == m && _customModel.text.trim().isEmpty,
                onSelected: (_) => setState(() {
                  _suggestedModel = m;
                  _customModel.clear();
                }),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _suggestedModel == m ? Colors.white : null,
                ),
                selectedColor: DragonColors.ember,
                backgroundColor: DragonColors.card,
                side: BorderSide(color: DragonColors.stroke),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _customModel,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Or type any model id',
            hintText: 'anthropic/claude-sonnet-4',
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DragonColors.card.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DragonColors.stroke),
          ),
          child: Row(children: [
            const DragonMonogram(size: 26),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                'Dragon will remember what matters across sessions using its '
                'hybrid memory — facts, rules and resumable sessions.',
                style: TextStyle(fontSize: 12, height: 1.55, color: DragonColors.textDim),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
