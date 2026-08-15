import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamesScreen extends StatefulWidget {
  final String role;
  const GamesScreen({super.key, this.role = 'admin'});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final claimed = <String>{};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { claimed.addAll(prefs.getStringList('gajurmukhi_claimed_${widget.role}') ?? const []); loading = false; });
  }

  Future<void> _claim(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = {...claimed, id};
    await prefs.setStringList('gajurmukhi_claimed_${widget.role}', updated.toList());
    if (mounted) setState(() => claimed.add(id));
  }

  List<Map<String, Object>> get challenges {
    switch (widget.role) {
      case 'collector':
        return [
          {'id': 'collection', 'title': 'Collection streak', 'description': 'Complete the morning and evening collection entries.', 'points': 40, 'progress': 0.65, 'icon': Icons.local_drink},
          {'id': 'accuracy', 'title': 'Quality champion', 'description': 'Record FAT and SNF values for every collection today.', 'points': 30, 'progress': 0.40, 'icon': Icons.science_outlined},
        ];
      case 'shop':
        return [
          {'id': 'counter', 'title': 'Counter momentum', 'description': 'Complete 10 accurate bills with no pending drafts.', 'points': 50, 'progress': 0.70, 'icon': Icons.point_of_sale},
          {'id': 'stock', 'title': 'Stock guardian', 'description': 'Review all low-stock items before closing time.', 'points': 25, 'progress': 0.50, 'icon': Icons.inventory_2_outlined},
        ];
      case 'customer':
        return [
          {'id': 'order', 'title': 'Fresh basket', 'description': 'Place a scheduled dairy or grocery order.', 'points': 20, 'progress': 0.30, 'icon': Icons.shopping_basket_outlined},
          {'id': 'feedback', 'title': 'Helpful customer', 'description': 'Confirm delivery and share useful feedback.', 'points': 10, 'progress': 0.0, 'icon': Icons.thumb_up_alt_outlined},
        ];
      default:
        return [
          {'id': 'sales', 'title': 'Healthy business day', 'description': 'Review sales, collection, stock, and outstanding balances.', 'points': 60, 'progress': 0.55, 'icon': Icons.insights},
          {'id': 'team', 'title': 'Team sync', 'description': 'Check staff activity and close all pending actions.', 'points': 40, 'progress': 0.35, 'icon': Icons.groups_outlined},
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Daily progress', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Useful challenges for ${widget.role} work. Rewards are local progress points, not cash or gambling.'),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xffe9f4ff),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const CircleAvatar(backgroundColor: Color(0xff1976e8), foregroundColor: Colors.white, child: Icon(Icons.emoji_events_outlined)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Today’s points', style: TextStyle(fontWeight: FontWeight.w600)), Text('${claimed.length * 10} points earned', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))])),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          ...challenges.map((challenge) {
            final id = challenge['id']! as String;
            final progress = challenge['progress']! as double;
            final points = challenge['points']! as int;
            final isClaimed = claimed.contains(id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [CircleAvatar(child: Icon(challenge['icon']! as IconData)), const SizedBox(width: 12), Expanded(child: Text(challenge['title']! as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))), Text('$points pts')]),
                  const SizedBox(height: 8),
                  Text(challenge['description']! as String),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress, minHeight: 7, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: FilledButton.tonal(onPressed: isClaimed ? null : () => _claim(id), child: Text(isClaimed ? 'Claimed' : progress >= 0.7 ? 'Claim reward' : 'Keep going'))),
                ]),
              ),
            );
          }),
        ],
      );
  }
}
