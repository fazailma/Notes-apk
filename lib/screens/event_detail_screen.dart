import 'package:flutter/material.dart';
import 'package:your_creative_notebook/models/event.dart';
import 'package:your_creative_notebook/services/pocketbase_service.dart';
import 'package:your_creative_notebook/screens/edit_event_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final PocketbaseService _pbService = PocketbaseService();
  bool _isLoading = false;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Acara'),
        content: const Text('Apakah Anda yakin ingin menghapus acara ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _pbService.deleteEvent(widget.event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Acara berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate changes
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus acara: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editEvent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventScreen(event: widget.event),
      ),
    );

    if (result == true) {
      // Return true to indicate changes
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _scheduleNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'your_channel_id',
        'your_channel_name',
        channelDescription: 'your_channel_description',
        importance: Importance.max,
        priority: Priority.high,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

    // Menentukan waktu notifikasi
    DateTime scheduledDate;
    if (widget.event.reminder != null) {
      // Jika ada reminder, jadwalkan sesuai dengan reminder
      scheduledDate = DateTime.now().add(Duration(minutes: widget.event.reminder!));
    } else {
      // Jika tidak ada reminder, jadwalkan sekarang
      scheduledDate = DateTime.now();
    }

    // PERBAIKAN: Gunakan data event yang sebenarnya
    String notificationTitle = widget.event.title;
    String notificationBody = widget.event.description ?? 'Acara akan segera dimulai';
    
    // Jika ada reminder, tambahkan info waktu
    if (widget.event.reminder != null && widget.event.reminder! > 0) {
      notificationBody = '${widget.event.description ?? widget.event.title} - ${_getReminderText(widget.event.reminder!)}';
    }

    // Menggunakan zonedSchedule sebagai pengganti schedule
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      widget.event.id.hashCode,
      notificationTitle, // Gunakan judul event yang sebenarnya
      notificationBody,  // Gunakan deskripsi event yang sebenarnya
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pengingat untuk "${widget.event.title}" berhasil dijadwalkan'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal menjadwalkan pengingat: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Acara'),
        actions: [
          IconButton(
            onPressed: _editEvent,
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: _isLoading ? null : _deleteEvent,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete, color: Colors.red),
          ),
          if (widget.event.reminder != null)
            IconButton(
              onPressed: _scheduleNotification,
              icon: const Icon(Icons.notifications),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.event.colorValue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.event.colorValue.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.event.description != null && widget.event.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.event.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date & Time
            _buildInfoCard(
              icon: Icons.access_time,
              title: 'Waktu',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.formattedDate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.event.formattedTime,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Location
            if (widget.event.location != null && widget.event.location!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.location_on,
                title: 'Lokasi',
                content: Text(
                  widget.event.location!,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],

            // Reminder
            if (widget.event.reminder != null) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.notifications,
                title: 'Pengingat',
                content: Text(
                  _getReminderText(widget.event.reminder!),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],

            // Color
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.palette,
              title: 'Warna',
              content: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.event.colorValue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.event.color ?? 'Default',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            // Created & Updated
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Tambahan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dibuat: ${_formatDateTime(widget.event.created)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'Diperbarui: ${_formatDateTime(widget.event.updated)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: widget.event.colorValue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getReminderText(int minutes) {
    if (minutes == 0) return 'Tidak ada pengingat';
    if (minutes < 60) return '$minutes menit sebelumnya';
    if (minutes < 1440) return '${minutes ~/ 60} jam sebelumnya';
    return '${minutes ~/ 1440} hari sebelumnya';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
