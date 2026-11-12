import 'package:flutter/material.dart';

class O13ServiceHistoryScreen extends StatefulWidget {
  final String vehicleName;
  final bool initialUnderRepair;

  const O13ServiceHistoryScreen({
    super.key,
    this.vehicleName = 'Bicycle B03',
    this.initialUnderRepair = true,
  });

  @override
  State<O13ServiceHistoryScreen> createState() =>
      _O13ServiceHistoryScreenState();
}

class _O13ServiceHistoryScreenState extends State<O13ServiceHistoryScreen> {
  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  late bool _underRepair;
  final _workController = TextEditingController();
  final _dateController = TextEditingController();

  final List<Map<String, String>> _history = [
    {'work': 'Replaced tyre', 'date': '28 Oct 2026'},
    {'work': 'General check', 'date': '14 Oct 2026'},
    {'work': 'Adjusted brakes', 'date': '02 Oct 2026'},
  ];

  @override
  void initState() {
    super.initState();
    _underRepair = widget.initialUnderRepair;
  }

  @override
  void dispose() {
    _workController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _saveRecord() {
    final work = _workController.text.trim();
    final date = _dateController.text.trim();
    if (work.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter work done')),
      );
      return;
    }

    setState(() {
      _history.insert(0, {
        'work': work,
        'date': date.isEmpty ? '12 Nov 2026' : date,
      });
      _workController.clear();
      _dateController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Maintenance record saved'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          widget.vehicleName,
          style: const TextStyle(
            color: _dark,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Under repair toggle row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Under repair (cannot be booked)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
                Switch(
                  value: _underRepair,
                  activeColor: Colors.white,
                  activeTrackColor: _dark,
                  onChanged: (val) => setState(() => _underRepair = val),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Reported by customers
            const Text(
              'Reported by customers',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Brakes feel loose',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '10 Nov 2026 · after rental by ahmad_rides',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Record maintenance form
            const Text(
              'Record maintenance',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Work done',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _workController,
              style: const TextStyle(fontSize: 14, color: _dark),
              decoration:
                  _inputDecoration('e.g. Adjusted brakes, replaced chain'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Date',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _dateController,
              style: const TextStyle(fontSize: 14, color: _dark),
              decoration: _inputDecoration('e.g. 12 Nov 2026'),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save record',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Service history list
            const Text(
              'Service history',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _border),
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['work']!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['date']!,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _dark, width: 1.5),
      ),
    );
  }
}
