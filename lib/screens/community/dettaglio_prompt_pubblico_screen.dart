import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/providers/community_provider.dart';
import 'package:ideai/providers/prompt_generato_provider.dart';
import 'package:ideai/models/prompt_pubblico.dart';
import 'package:ideai/models/prompt_generato.dart';

/// Schermata dettaglio di un prompt pubblico della community.
/// Mostra prompt strutturato, bottoni like/fork, sezione commenti.
class DettaglioPromptPubblicoScreen extends StatefulWidget {
  const DettaglioPromptPubblicoScreen({super.key});

  @override
  State<DettaglioPromptPubblicoScreen> createState() =>
      _DettaglioPromptPubblicoScreenState();
}

class _DettaglioPromptPubblicoScreenState
    extends State<DettaglioPromptPubblicoScreen> {
  /// Controller per il campo commento
  final _commentoController = TextEditingController();

  @override
  void dispose() {
    _commentoController.dispose();
    super.dispose();
  }

  /// Mappa nome icona → IconData Material
  IconData _getIcona(String nome) {
    switch (nome) {
      case 'person':
        return Icons.person_outline;
      case 'info':
        return Icons.info_outline;
      case 'list':
        return Icons.format_list_bulleted;
      case 'format_align_left':
        return Icons.format_align_left;
      case 'block':
        return Icons.block;
      // Icone delle sezioni dedicate alla categoria Immagini
      case 'image':
        return Icons.image_outlined;
      case 'palette':
        return Icons.palette_outlined;
      case 'brightness':
        return Icons.wb_sunny_outlined;
      case 'crop':
        return Icons.crop;
      default:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final promptId = ModalRoute.of(context)?.settings.arguments as String?;
    if (promptId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Errore')),
        body: const Center(child: Text('Prompt non trovato')),
      );
    }

    final community = Provider.of<CommunityProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Trova il prompt
    final index = community.promptPubblici.indexWhere((p) => p.id == promptId);
    if (index == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Errore')),
        body: const Center(child: Text('Prompt non trovato')),
      );
    }
    final prompt = community.promptPubblici[index];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          prompt.titolo,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === HEADER — Autore e info ===
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(prompt.autoreColore),
                    child: Text(
                      prompt.autoreNome
                          .replaceFirst('@', '')[0]
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prompt.autoreNome,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formatData(prompt.dataPubblicazione),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Categoria
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      prompt.categoria,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Badge "Forkato da" se presente
            if (prompt.forkatoDaNome != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fork_right,
                          size: 14, color: Colors.purple[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Forkato da ${prompt.forkatoDaNome}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Descrizione
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                prompt.descrizione,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 8),

            // Stelle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ...List.generate(5, (i) {
                    final valore = prompt.punteggio - i;
                    return Icon(
                      valore >= 1
                          ? Icons.star
                          : valore >= 0.5
                              ? Icons.star_half
                              : Icons.star_border,
                      size: 18,
                      color: Colors.amber[600],
                    );
                  }),
                  const SizedBox(width: 6),
                  Text(
                    prompt.punteggio.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // === BARRA AZIONI — Like, Fork, Copia, Usa ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Like
                    _buildAzione(
                      context,
                      icona: prompt.haLike
                          ? Icons.favorite
                          : Icons.favorite_border,
                      etichetta: '${prompt.numerLike}',
                      colore: prompt.haLike ? Colors.red : null,
                      onTap: () => community.toggleLike(prompt.id),
                    ),
                    // Fork
                    _buildAzione(
                      context,
                      icona: Icons.fork_right,
                      etichetta: '${prompt.numeroFork}',
                      onTap: () {
                        community.forkPrompt(prompt);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Prompt forkato! Lo trovi nel tuo profilo.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    // Copia
                    _buildAzione(
                      context,
                      icona: Icons.copy_outlined,
                      etichetta: 'Copia',
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: prompt.testoCompleto));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Prompt copiato!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    // Usa questo prompt
                    _buildAzione(
                      context,
                      icona: Icons.play_arrow_outlined,
                      etichetta: 'Usa',
                      colore: colorScheme.primary,
                      onTap: () => _usaPrompt(prompt),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // === SEZIONI STRUTTURATE ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Prompt',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 12),

            ...prompt.sezioni.map((sezione) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: Color(sezione.colore),
                          width: 3,
                        ),
                      ),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                      ],
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      leading: Icon(
                        _getIcona(sezione.icona),
                        size: 20,
                        color: Color(sezione.colore),
                      ),
                      title: Text(
                        sezione.titolo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(sezione.colore),
                        ),
                      ),
                      children: [
                        SelectableText(
                          sezione.contenuto,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 8),

            // === TAG ===
            if (prompt.tag.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: prompt.tag
                      .map((tag) => Chip(
                            label: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            side: BorderSide.none,
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 24),

            // === COMMENTI ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Commenti',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${prompt.commenti.length}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Campo nuovo commento
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentoController,
                      decoration: InputDecoration(
                        hintText: 'Scrivi un commento...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      if (_commentoController.text.trim().isNotEmpty) {
                        community.aggiungiCommento(
                          prompt.id,
                          _commentoController.text.trim(),
                        );
                        _commentoController.clear();
                        FocusScope.of(context).unfocus();
                      }
                    },
                    icon: const Icon(Icons.send, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Lista commenti
            if (prompt.commenti.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Nessun commento ancora. Sii il primo!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: prompt.commenti.length,
                itemBuilder: (context, index) {
                  final commento = prompt.commenti[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(commento.autoreColore),
                          child: Text(
                            commento.autoreNome
                                .replaceFirst('@', '')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    commento.autoreNome,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDataBreve(commento.data),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color:
                                              colorScheme.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                commento.testo,
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Bottone azione nella barra (like, fork, copia, usa)
  Widget _buildAzione(
    BuildContext context, {
    required IconData icona,
    required String etichetta,
    Color? colore,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icona,
              size: 22,
              color: colore ?? colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              etichetta,
              style: TextStyle(
                fontSize: 11,
                color: colore ?? colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Usa questo prompt" — carica nel provider e naviga a post-generazione
  void _usaPrompt(PromptPubblico prompt) {
    final provider =
        Provider.of<PromptGeneratoProvider>(context, listen: false);
    provider.caricaPrompt(PromptGenerato(
      sezioni: prompt.sezioni,
      punteggioGlobale: prompt.punteggio,
      punteggiCriteri: {
        'Chiarezza': prompt.punteggio,
        'Specificità': prompt.punteggio * 0.9,
        'Completezza': prompt.punteggio * 0.95,
        'Struttura': prompt.punteggio * 1.02 > 5.0
            ? 5.0
            : prompt.punteggio * 1.02,
        'Coerenza': prompt.punteggio * 0.98,
      },
      suggerimenti: [],
    ));
    Navigator.of(context).pushNamed(AppRoutes.postGenerazione);
  }

  /// Formatta data estesa
  String _formatData(DateTime data) {
    const mesi = [
      'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
      'lug', 'ago', 'set', 'ott', 'nov', 'dic',
    ];
    return '${data.day} ${mesi[data.month - 1]} ${data.year}';
  }

  /// Formatta data breve
  String _formatDataBreve(DateTime data) {
    final ora = DateTime.now();
    final diff = ora.difference(data);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m fa';
    if (diff.inHours < 24) return '${diff.inHours}h fa';
    if (diff.inDays < 7) return '${diff.inDays}g fa';
    return _formatData(data);
  }
}
