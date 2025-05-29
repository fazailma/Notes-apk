import 'package:flutter/material.dart';
import 'package:your_creative_notebook/services/pocketbase_service.dart';

class AddEventScreen extends StatefulWidget {
  final DateTime? selectedDate;

  const AddEventScreen({super.key, this.selectedDate});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  final PocketbaseService _pbService = PocketbaseService();
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().add(const Duration(hours: 1));
  bool _allDay = false;
  Color _selectedColor = Colors.blue;
  int? _reminder;
  bool _isLoading = false;

  final List<Color> _eventColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  final List<int> _reminderOptions = [
    0, // No reminder
    5, // 5 minutes
    15, // 15 minutes
    30, // 30 minutes
    60, // 1 hour
    1440, // 1 day
  ];

  @override
  void initState() {
    super.initState();
    if (widget.selectedDate != null) {
      _startDate = widget.selectedDate!;
      _endDate = widget.selectedDate!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _getReminderText(int minutes) {
    if (minutes == 0) return 'Tidak ada pengingat';
    if (minutes < 60) return '$minutes menit sebelumnya';
    if (minutes < 1440) return '${minutes ~/ 60} jam sebelumnya';
    return '${minutes ~/ 1440} hari sebelumnya';
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020), // Allow past dates
      lastDate: DateTime(2030),  // Extended future dates
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Jika tanggal mulai lebih besar dari tanggal selesai, update tanggal selesai
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          // Jika tanggal selesai lebih kecil dari tanggal mulai, update tanggal mulai
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      DateTime startDateTime;
      DateTime endDateTime;

      if (_allDay) {
        startDateTime = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0);
        endDateTime = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59);
      } else {
        startDateTime = _combineDateTime(_startDate, _startTime);
        endDateTime = _combineDateTime(_endDate, _endTime);
      }

      // Validasi waktu
      if (endDateTime.isBefore(startDateTime)) {
        throw Exception('Waktu selesai tidak boleh lebih awal dari waktu mulai');
      }

      await _pbService.createEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        startDate: startDateTime,
        endDate: endDateTime,
        allDay: _allDay,
        color: '#${_selectedColor.value.toRadixString(16).substring(2)}',
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        reminder: _reminder,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acara berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan acara: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Acara'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveEvent,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Simpan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul Acara *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Judul acara wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // All Day Toggle
            SwitchListTile(
              title: const Text('Sepanjang Hari'),
              subtitle: const Text('Acara berlangsung sepanjang hari'),
              value: _allDay,
              onChanged: (value) {
                setState(() {
                  _allDay = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Start Date & Time
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Tanggal Mulai'),
                    subtitle: Text(
                      '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                    ),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context, true),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                if (!_allDay) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      title: const Text('Waktu Mulai'),
                      subtitle: Text(_startTime.format(context)),
                      leading: const Icon(Icons.access_time),
                      onTap: () => _selectTime(context, true),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // End Date & Time
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Tanggal Selesai'),
                    subtitle: Text(
                      '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                    ),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context, false),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                if (!_allDay) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      title: const Text('Waktu Selesai'),
                      subtitle: Text(_endTime.format(context)),
                      leading: const Icon(Icons.access_time),
                      onTap: () => _selectTime(context, false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Lokasi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            // Color Selection
            const Text(
              'Warna Acara',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _eventColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Reminder
            const Text(
              'Pengingat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: _reminder == 0 ? null : _reminder,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notifications),
              ),
              items: _reminderOptions.map((minutes) {
                return DropdownMenuItem<int?>(
                  value: minutes == 0 ? null : minutes,
                  child: Text(_getReminderText(minutes)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _reminder = value;
                });
              },
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveEvent,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Simpan Acara',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

extension TimeOfDayExtension on TimeOfDay {
  TimeOfDay add(Duration duration) {
    final minutes = hour * 60 + minute + duration.inMinutes;
    return TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);
  }
}
