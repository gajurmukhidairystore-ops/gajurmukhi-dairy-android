import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class MusicScreen extends StatefulWidget {
  final String role;
  const MusicScreen({super.key, this.role = 'admin'});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  static const _storageKey = 'gajurmukhi_youtube_playlist';
  final link = TextEditingController();
  List<String> links = [];
  YoutubePlayerController? controller;
  int currentIndex = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey) ?? [];
    if (!mounted) return;
    setState(() { links = saved; loading = false; });
    if (saved.isNotEmpty) _selectVideo(0, autoPlay: false);
  }

  String? _videoId(String value) => YoutubePlayerController.convertUrlToId(value.trim());

  Future<void> _saveLink() async {
    final value = link.text.trim();
    if (_videoId(value) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a YouTube video link. Playlist pages can be saved for reference, but in-app controls require video links.')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final updated = [...links, value];
    await prefs.setStringList(_storageKey, updated);
    if (!mounted) return;
    setState(() { links = updated; link.clear(); });
    _selectVideo(updated.length - 1);
  }

  void _selectVideo(int index, {bool autoPlay = true}) {
    if (index < 0 || index >= links.length) return;
    final id = _videoId(links[index]);
    if (id == null) return;
    controller?.close();
    final next = YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: autoPlay,
      params: const YoutubePlayerParams(showControls: true, showFullscreenButton: true, privacyEnhanced: true),
    );
    setState(() { controller = next; currentIndex = index; });
  }

  void _next() { if (links.length > 1) _selectVideo((currentIndex + 1) % links.length); }
  void _previous() { if (links.length > 1) _selectVideo((currentIndex - 1 + links.length) % links.length); }

  Future<void> _remove(int index) async {
    final updated = [...links]..removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, updated);
    if (!mounted) return;
    setState(() => links = updated);
    if (updated.isEmpty) {
      controller?.close();
      setState(() => controller = null);
    } else {
      _selectVideo(index.clamp(0, updated.length - 1).toInt(), autoPlay: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('YouTube Music', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('In-app player for ${widget.role}. Use the player controls, then switch tracks with Previous or Next.'),
        const SizedBox(height: 14),
        if (controller != null) ...[
          YoutubePlayer(controller: controller!),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: links.length > 1 ? _previous : null, icon: const Icon(Icons.skip_previous)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Text('Use player controls above')),
            IconButton(onPressed: links.length > 1 ? _next : null, icon: const Icon(Icons.skip_next)),
          ]),
          const SizedBox(height: 10),
        ],
        TextField(controller: link, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'YouTube video URL', prefixIcon: Icon(Icons.link))),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _saveLink, icon: const Icon(Icons.add), label: const Text('Add to playlist')),
        const SizedBox(height: 14),
        if (links.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No saved videos yet. Add a YouTube video link to begin.'))),
        ...links.asMap().entries.map((entry) => Card(child: ListTile(selected: entry.key == currentIndex, leading: const Icon(Icons.play_circle_fill, color: Colors.red), title: Text('Video ${entry.key + 1}'), subtitle: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _selectVideo(entry.key), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _remove(entry.key))))),
        const SizedBox(height: 8),
        const Text('This feature uses the official YouTube iFrame player API. It does not download, extract, cache, or redistribute audio.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  @override
  void dispose() { controller?.close(); link.dispose(); super.dispose(); }
}
