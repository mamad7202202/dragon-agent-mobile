/// Built-in provider presets — mirrors the desktop Dragon Agent presets.
library;

enum Protocol { openai, anthropic }

class Preset {
  final String name;
  final String label;
  final String baseUrl;
  final Protocol protocol;
  final List<String> models;
  final bool keyRequired;
  final String note;
  final String glyph;
  final int colorSeed;

  const Preset({
    required this.name,
    required this.label,
    required this.baseUrl,
    required this.protocol,
    required this.models,
    required this.keyRequired,
    required this.note,
    required this.glyph,
    required this.colorSeed,
  });
}

const presets = <Preset>[
  Preset(
    name: 'google',
    label: 'Google AI Studio',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    protocol: Protocol.openai,
    models: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash'],
    keyRequired: true,
    note: 'Free key at aistudio.google.com/apikey',
    glyph: 'G',
    colorSeed: 0xFF4285F4,
  ),
  Preset(
    name: 'openrouter',
    label: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    protocol: Protocol.openai,
    models: [
      'anthropic/claude-sonnet-4',
      'openai/gpt-4o',
      'google/gemini-2.5-pro',
      'meta-llama/llama-3.3-70b-instruct',
      'deepseek/deepseek-chat',
    ],
    keyRequired: true,
    note: '400+ models behind one key · openrouter.ai/keys',
    glyph: 'O',
    colorSeed: 0xFF8B5CF6,
  ),
  Preset(
    name: 'openai',
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    protocol: Protocol.openai,
    models: ['gpt-4o-mini', 'gpt-4o'],
    keyRequired: true,
    note: 'Key at platform.openai.com/api-keys',
    glyph: 'A',
    colorSeed: 0xFF10A37F,
  ),
  Preset(
    name: 'anthropic',
    label: 'Anthropic (Claude)',
    baseUrl: 'https://api.anthropic.com/v1',
    protocol: Protocol.anthropic,
    models: ['claude-sonnet-4-20250514', 'claude-3-5-haiku-latest'],
    keyRequired: true,
    note: 'Native protocol · console.anthropic.com',
    glyph: 'C',
    colorSeed: 0xFFD97757,
  ),
  Preset(
    name: 'groq',
    label: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    protocol: Protocol.openai,
    models: ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'],
    keyRequired: true,
    note: 'Ultra-fast inference · console.groq.com/keys',
    glyph: 'Q',
    colorSeed: 0xFFF55036,
  ),
  Preset(
    name: 'deepseek',
    label: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    protocol: Protocol.openai,
    models: ['deepseek-chat', 'deepseek-reasoner'],
    keyRequired: true,
    note: 'Key at platform.deepseek.com',
    glyph: 'D',
    colorSeed: 0xFF2563EB,
  ),
  Preset(
    name: 'ollama',
    label: 'Ollama',
    baseUrl: 'http://localhost:11434/v1',
    protocol: Protocol.openai,
    models: ['llama3.1', 'qwen2.5-coder'],
    keyRequired: false,
    note: 'Local — on mobile use your PC LAN IP, e.g. http://192.168.1.10:11434/v1',
    glyph: 'L',
    colorSeed: 0xFFE5E7EB,
  ),
  Preset(
    name: 'lmstudio',
    label: 'LM Studio',
    baseUrl: 'http://localhost:1234/v1',
    protocol: Protocol.openai,
    models: ['local-model'],
    keyRequired: false,
    note: 'Start the LM Studio server, then use its LAN address here',
    glyph: 'M',
    colorSeed: 0xFF38BDF8,
  ),
  Preset(
    name: 'custom',
    label: 'Custom endpoint',
    baseUrl: '',
    protocol: Protocol.openai,
    models: [],
    keyRequired: false,
    note: 'Any other OpenAI-compatible endpoint',
    glyph: '+',
    colorSeed: 0xFFFF6A3D,
  ),
];

Preset findPreset(String name) =>
    presets.firstWhere((p) => p.name == name, orElse: () => presets.last);
