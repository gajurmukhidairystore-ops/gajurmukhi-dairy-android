import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class MusicScreen extends StatefulWidget {
  final String role;
  const MusicScreen({super.key, this.role = 'admin'});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  static const _libraryKey = 'gajurmukhi_music_library_v2';
  static const _playlistsKey = 'gajurmukhi_music_playlists_v2';
  static const _selectedPlaylistKey = 'gajurmukhi_music_selected_playlist';

  final title = TextEditingController();
  final source = TextEditingController();
  final playlistName = TextEditingController();
  final audioPlayer = ja.AudioPlayer();
  StreamSubscription<Duration>? positionSubscription;
  StreamSubscription<Duration?>? durationSubscription;
  StreamSubscription<ja.PlayerState>? playerStateSubscription;
  final List<Map<String, String>> tracks = [];
  final Map<String, List<String>> playlists = {};
  YoutubePlayerController? youtubeController;

  String selectedPlaylist = 'My Playlist';
  String? currentTrackId;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool loading = true;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    positionSubscription = audioPlayer.positionStream.listen((value) {
      if (mounted) setState(() => position = value);
    });
    durationSubscription = audioPlayer.durationStream.listen((value) {
      if (mounted) setState(() => duration = value ?? Duration.zero);
    });
    playerStateSubscription = audioPlayer.playerStateStream.listen((value) {
      if (value.processingState == ja.ProcessingState.completed) {
        _next();
      } else if (mounted) {
        setState(() => isPlaying = value.playing);
      }
    });
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTracks = prefs.getString(_libraryKey);
    final savedPlaylists = prefs.getString(_playlistsKey);
    final oldYoutubeLinks = prefs.getStringList('gajurmukhi_youtube_playlist') ?? [];

    if (savedTracks != null) {
      try {
        final decoded = jsonDecode(savedTracks) as List<dynamic>;
        tracks.addAll(decoded.map((item) => Map<String, String>.from(item as Map)));
      } catch (_) {
        // Ignore an invalid local library and start with an empty one.
      }
    }
    if (savedPlaylists != null) {
      try {
        final decoded = jsonDecode(savedPlaylists) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          playlists[key] = List<String>.from(value as List<dynamic>);
        });
      } catch (_) {
        // Rebuild the playlist index when old data is malformed.
      }
    }
    if (tracks.isEmpty && oldYoutubeLinks.isNotEmpty) {
      for (final link in oldYoutubeLinks) {
        final id = _newId();
        tracks.add({'id': id, 'title': 'YouTube video', 'type': 'youtube', 'source': link});
        playlists.putIfAbsent('My Playlist', () => []).add(id);
      }
    }
    if (playlists.isEmpty) playlists['My Playlist'] = tracks.map((item) => item['id']!).toList();
    if (!playlists.containsKey('My Playlist')) playlists['My Playlist'] = [];
    selectedPlaylist = prefs.getString(_selectedPlaylistKey) ?? playlists.keys.first;
    if (!playlists.containsKey(selectedPlaylist)) selectedPlaylist = playlists.keys.first;
    if (!mounted) return;
    setState(() => loading = false);
    await _saveLibrary();
    final visible = _visibleTracks;
    if (visible.isNotEmpty) await _selectTrack(0, autoPlay: false);
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${tracks.length}';

  List<Map<String, String>> get _visibleTracks {
    final ids = playlists[selectedPlaylist] ?? [];
    return ids.map(_trackById).whereType<Map<String, String>>().toList();
  }

  Map<String, String>? _trackById(String id) {
    for (final track in tracks) {
      if (track['id'] == id) return track;
    }
    return null;
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_libraryKey, jsonEncode(tracks));
    await prefs.setString(_playlistsKey, jsonEncode(playlists));
    await prefs.setString(_selectedPlaylistKey, selectedPlaylist);
  }

  String? _youtubeId(String value) => YoutubePlayerController.convertUrlToId(value.trim());

  bool _isDirectAudioUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return false;
    return RegExp(r'\.(mp3|m4a|wav|aac|ogg)(\?.*)?$', caseSensitive: false).hasMatch(uri.path + (uri.hasQuery ? '?${uri.query}' : ''));
  }

  Future<void> _addYoutube() async {
    final value = source.text.trim();
    if (_youtubeId(value) == null) {
      _notice('Add a valid YouTube video URL. The official YouTube player stays online and is not downloaded.');
      return;
    }
    await _addTrack({'id': _newId(), 'title': title.text.trim().isEmpty ? 'YouTube video' : title.text.trim(), 'type': 'youtube', 'source': value});
  }

  Future<void> _addStream() async {
    final value = source.text.trim();
    if (!_isDirectAudioUrl(value)) {
      _notice('Use an authorized direct MP3, M4A, WAV, AAC, or OGG stream URL. YouTube links belong in the YouTube field.');
      return;
    }
    await _addTrack({'id': _newId(), 'title': title.text.trim().isEmpty ? 'Online audio' : title.text.trim(), 'type': 'stream', 'source': value});
  }

  Future<void> _addLocalFile() async {
    final picked = await FilePicker.platform.pickFiles(withData: false, type: FileType.custom, allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg']);
    final path = picked?.files.single.path;
    if (path == null || path.trim().isEmpty) return;
    final fileName = path.split(Platform.pathSeparator).last;
    await _addTrack({'id': _newId(), 'title': fileName, 'type': 'local', 'source': path});
  }

  Future<void> _addTrack(Map<String, String> track) async {
    tracks.add(track);
    playlists.putIfAbsent(selectedPlaylist, () => []).add(track['id']!);
    await _saveLibrary();
    if (!mounted) return;
    setState(() {
      title.clear();
      source.clear();
    });
    await _selectTrack(_visibleTracks.length - 1);
  }

  Future<void> _downloadAuthorizedStream(Map<String, String> track) async {
    final url = track['source'] ?? '';
    if (!_isDirectAudioUrl(url)) {
      _notice('Only authorized direct audio URLs can be downloaded for offline playback.');
      return;
    }
    try {
      _notice('Downloading authorized audio…');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) throw StateError('The audio server did not return a playable file');
      if (response.bodyBytes.length > 150 * 1024 * 1024) throw StateError('This audio file is larger than the 150 MB offline limit');
      final directory = await getApplicationDocumentsDirectory();
      final musicDirectory = Directory('${directory.path}/gajurmukhi_music');
      await musicDirectory.create(recursive: true);
      final rawName = Uri.parse(url).pathSegments.isEmpty ? '${track['id']}.mp3' : Uri.parse(url).pathSegments.last;
      final safeName = rawName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final savedPath = '${musicDirectory.path}/$safeName';
      await File(savedPath).writeAsBytes(response.bodyBytes, flush: true);
      track['type'] = 'local';
      track['source'] = savedPath;
      await _saveLibrary();
      if (mounted) {
        setState(() {});
        _notice('Saved for offline playback');
      }
    } catch (error) {
      _notice('Download failed: $error');
    }
  }

  Future<void> _selectTrack(int index, {bool autoPlay = true}) async {
    final visible = _visibleTracks;
    if (index < 0 || index >= visible.length) return;
    final track = visible[index];
    final id = track['id'];
    if (id == null) return;
    currentTrackId = id;
    await audioPlayer.stop();
    youtubeController?.close();
    youtubeController = null;
    position = Duration.zero;
    duration = Duration.zero;
    if (track['type'] == 'youtube') {
      final videoId = _youtubeId(track['source'] ?? '');
      if (videoId == null) return;
      youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: autoPlay,
        params: const YoutubePlayerParams(showControls: true, showFullscreenButton: true, privacyEnhancedMode: true),
      );
    } else {
      final path = track['source'] ?? '';
      final mediaItem = MediaItem(id: id, title: track['title'] ?? 'Audio', artist: 'Gajurmukhi Dairy & Store');
      if (track['type'] == 'local') {
        await audioPlayer.setAudioSource(ja.AudioSource.file(path, tag: mediaItem));
      } else {
        await audioPlayer.setAudioSource(ja.AudioSource.uri(Uri.parse(path), tag: mediaItem));
      }
      if (autoPlay) await audioPlayer.play();
    }
    if (mounted) setState(() {});
  }

  Map<String, String>? get _currentTrack => currentTrackId == null ? null : _trackById(currentTrackId!);

  Future<void> _toggleAudio() async {
    final track = _currentTrack;
    if (track == null || track['type'] == 'youtube') return;
    if (isPlaying) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play();
    }
  }

  Future<void> _next() async {
    final visible = _visibleTracks;
    final current = visible.indexWhere((track) => track['id'] == currentTrackId);
    if (visible.length > 1) await _selectTrack((current + 1) % visible.length);
  }

  Future<void> _previous() async {
    final visible = _visibleTracks;
    final current = visible.indexWhere((track) => track['id'] == currentTrackId);
    if (visible.length > 1) await _selectTrack((current - 1 + visible.length) % visible.length);
  }

  Future<void> _removeFromPlaylist(Map<String, String> track) async {
    final id = track['id'];
    if (id == null) return;
    playlists[selectedPlaylist]?.remove(id);
    if (currentTrackId == id) {
      await audioPlayer.stop();
      youtubeController?.close();
      youtubeController = null;
      currentTrackId = null;
    }
    await _saveLibrary();
    if (mounted) setState(() {});
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Create playlist'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Playlist name')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Create'))],
    ));
    controller.dispose();
    if (name == null || name.isEmpty || playlists.containsKey(name)) return;
    playlists[name] = [];
    selectedPlaylist = name;
    await _saveLibrary();
    if (mounted) setState(() {});
  }

  Future<void> _addCurrentToPlaylist() async {
    final track = _currentTrack;
    if (track == null) return;
    final target = await showDialog<String>(context: context, builder: (dialogContext) => SimpleDialog(
      title: const Text('Add to playlist'),
      children: playlists.keys.map((name) => SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, name), child: Text(name))).toList(),
    ));
    if (target == null) return;
    final id = track['id']!;
    if (!(playlists[target] ?? []).contains(id)) playlists[target]!.add(id);
    await _saveLibrary();
    if (mounted) setState(() {});
  }

  void _notice(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${value.inHours > 0 ? '${value.inHours}:' : ''}$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final current = _currentTrack;
    final maxSeconds = duration.inSeconds.toDouble();
    final sliderValue = position.inSeconds.clamp(0, duration.inSeconds).toDouble();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Music Player', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Online streams, local audio, and personal playlists for ${widget.role}. YouTube remains inside the official player.'),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.folder_open)),
            title: const Text('Add music from phone files'),
            subtitle: const Text('Choose your own MP3, M4A, WAV, AAC, or OGG file. It stays available in your personal playlist.'),
            trailing: FilledButton.icon(onPressed: _addLocalFile, icon: const Icon(Icons.audio_file), label: const Text('Choose file')),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: playlists.keys.map((name) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(name), selected: name == selectedPlaylist, onSelected: (_) async { selectedPlaylist = name; await _saveLibrary(); if (mounted) setState(() {}); }))).toList())),
        const SizedBox(height: 12),
        if (youtubeController != null) YoutubePlayer(controller: youtubeController!),
        if (current != null && current['type'] != 'youtube') ...[
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: Text(current['title'] ?? 'Audio', style: const TextStyle(fontWeight: FontWeight.bold))),
            Slider(value: sliderValue, max: maxSeconds <= 0 ? 1 : maxSeconds, onChanged: maxSeconds <= 0 ? null : (value) async => audioPlayer.seek(Duration(seconds: value.round()))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_time(position)), Text(_time(duration))]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton(onPressed: _previous, icon: const Icon(Icons.skip_previous)), IconButton(onPressed: _toggleAudio, icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle, size: 42)), IconButton(onPressed: _next, icon: const Icon(Icons.skip_next)), IconButton(onPressed: () async { await audioPlayer.stop(); if (mounted) setState(() => isPlaying = false); }, icon: const Icon(Icons.stop))]),
          ]))),
        ],
        if (current != null) Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: _addCurrentToPlaylist, icon: const Icon(Icons.playlist_add), label: const Text('Add current to playlist'))),
        ExpansionTile(
          initiallyExpanded: tracks.isEmpty,
          tilePadding: EdgeInsets.zero,
          title: const Text('Add online music or stream'),
          subtitle: const Text('Use authorized streams or files you own/have permission to play'),
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Track title')),
            const SizedBox(height: 8),
            TextField(controller: source, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'YouTube URL or direct audio URL', prefixIcon: Icon(Icons.link))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [FilledButton.icon(onPressed: _addYoutube, icon: const Icon(Icons.ondemand_video), label: const Text('Add YouTube')), OutlinedButton.icon(onPressed: _addStream, icon: const Icon(Icons.wifi), label: const Text('Add stream')), OutlinedButton.icon(onPressed: _addLocalFile, icon: const Icon(Icons.audio_file), label: const Text('Choose phone file'))]),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _createPlaylist, icon: const Icon(Icons.create_new_folder), label: const Text('Create personal playlist')),
          ],
        ),
        const SizedBox(height: 8),
        if (_visibleTracks.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('This playlist is empty. Add a YouTube video, authorized stream, or local MP3 file.'))),
        ..._visibleTracks.asMap().entries.map((entry) {
          final track = entry.value;
          final isCurrent = track['id'] == currentTrackId;
          final isLocal = track['type'] == 'local';
          return Card(child: ListTile(selected: isCurrent, leading: Icon(track['type'] == 'youtube' ? Icons.ondemand_video : isLocal ? Icons.offline_bolt : Icons.wifi), title: Text(track['title'] ?? 'Audio'), subtitle: Text(isLocal ? 'Offline audio available' : track['source'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _selectTrack(entry.key), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (track['type'] == 'stream') IconButton(tooltip: 'Save for offline', onPressed: () => _downloadAuthorizedStream(track), icon: const Icon(Icons.download_for_offline)), IconButton(tooltip: 'Remove from playlist', onPressed: () => _removeFromPlaylist(track), icon: const Icon(Icons.remove_circle_outline))])));
        }),
        const SizedBox(height: 10),
        const Text('Copyright notice: YouTube playback uses the official embedded player. Offline downloads are limited to direct audio URLs that you own or are authorized to download; the app does not extract or download YouTube audio.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  @override
  void dispose() {
    youtubeController?.close();
    positionSubscription?.cancel();
    durationSubscription?.cancel();
    playerStateSubscription?.cancel();
    audioPlayer.dispose();
    title.dispose();
    source.dispose();
    playlistName.dispose();
    super.dispose();
  }
}
