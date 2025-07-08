import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Attendance System',
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Color(0xFF1E293B),
          secondary: Color(0xFFFFD700),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: DashboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum FilterStatus { all, tepat, telat }

class DashboardPage extends StatefulWidget {
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Color darkBlue = Color(0xFF1E293B);
  final Color lightGray = Color(0xFFE2E8F0);
  final Color gold = Color(0xFFFFD700);
  DateTime? selectedDate;
  List<Map<String, dynamic>> allAttendance = [];

  FilterStatus _filterStatus = FilterStatus.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard Absensi'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {}); // Memicu rebuild dan refresh data dari Firebase
          await Future.delayed(Duration(milliseconds: 500)); // animasi refresh
        },
        child: SingleChildScrollView(
          physics:
              AlwaysScrollableScrollPhysics(), // agar bisa di-pull walau data sedikit
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDonutChart(),
              SizedBox(height: 32),
              Text(
                'Absensi Terbaru',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 12),
              _buildSearchAndFilterButtons(),
              SizedBox(height: 12),
              _buildLiveAttendanceList(),
              SizedBox(height: 32),
              Row(
                children: [
                  Text(
                    'Rekapitulasi Absensi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: darkBlue,
                    ),
                  ),
                  Spacer(),
                  OutlinedButton.icon(
                    icon: Icon(Icons.date_range, color: darkBlue),
                    label: Text(
                      selectedDate == null
                          ? 'Pilih Tanggal'
                          : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(color: darkBlue),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: darkBlue),
                    ),
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildRekapitulasiAbsensi(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterButtons() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() => _searchQuery = val.toLowerCase());
          },
          decoration: InputDecoration(
            hintText: 'Cari nama atau NIM...',
            prefixIcon: Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilterChip(
              label: Text('Semua'),
              selected: _filterStatus == FilterStatus.all,
              onSelected: (_) =>
                  setState(() => _filterStatus = FilterStatus.all),
            ),
            SizedBox(width: 8),
            FilterChip(
              label: Text('Tepat Waktu'),
              selected: _filterStatus == FilterStatus.tepat,
              onSelected: (_) =>
                  setState(() => _filterStatus = FilterStatus.tepat),
              selectedColor: Colors.green.shade100,
            ),
            SizedBox(width: 8),
            FilterChip(
              label: Text('Terlambat'),
              selected: _filterStatus == FilterStatus.telat,
              onSelected: (_) =>
                  setState(() => _filterStatus = FilterStatus.telat),
              selectedColor: Colors.orange.shade100,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDonutChart() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('attendance').onValue,
      builder: (context, snapshot) {
        final now = DateTime.now();
        final todayString =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

        int totalToday = 0;
        int totalTepat = 0;
        int totalTelat = 0;
        List<Map<String, dynamic>> todayAttendance = [];

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          Map<dynamic, dynamic> data =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          data.forEach((kelas, tahunMap) {
            if (tahunMap is Map) {
              tahunMap.forEach((tahun, absensiMap) {
                if (absensiMap is Map) {
                  absensiMap.forEach((key, value) {
                    final item = Map<String, dynamic>.from(value);
                    final ts = item['timestamp'] ?? '';
                    if (ts.startsWith(todayString)) {
                      todayAttendance.add(item);
                      totalToday++;
                      if ((item['status'] ?? '').toLowerCase().contains(
                        'tepat',
                      )) {
                        totalTepat++;
                      } else {
                        totalTelat++;
                      }
                    }
                  });
                }
              });
            }
          });
        }

        allAttendance = todayAttendance;

        return Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTodayCard(
                  Icons.check_circle,
                  totalTepat,
                  'Total Tepat Waktu',
                  Colors.green,
                ),
                SizedBox(width: 16),
                _buildTodayCard(
                  Icons.groups,
                  totalToday,
                  'Total Hari Ini',
                  Color(0xFFFFD700),
                ),
                SizedBox(width: 16),
                _buildTodayCard(
                  Icons.warning,
                  totalTelat,
                  'Total Terlambat',
                  Colors.orange,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodayCard(
    IconData icon,
    int total,
    String label,
    Color iconColor,
  ) {
    return Card(
      color: Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: iconColor),
            SizedBox(height: 10),
            Text(
              '$total',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 30,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAttendanceList() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('attendance').onValue,
      builder: (context, snapshot) {
        List<Map<String, dynamic>> attendanceList = [];

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map;
          data.forEach((kelas, tahunMap) {
            if (tahunMap is Map) {
              tahunMap.forEach((tahun, absensiMap) {
                if (absensiMap is Map) {
                  absensiMap.forEach((key, value) {
                    final item = Map<String, dynamic>.from(value);
                    if (item['timestamp'] != null &&
                        item['timestamp'].toString().isNotEmpty) {
                      attendanceList.add(item);
                    }
                  });
                }
              });
            }
          });
        }

        attendanceList.sort(
          (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
        );

        List<Map<String, dynamic>> filteredList = attendanceList.where((item) {
          final nama = (item['nama'] ?? '').toString().toLowerCase();
          final nim = (item['nim'] ?? '').toString().toLowerCase();
          final status = (item['status'] ?? '').toString().toLowerCase();

          bool matchesQuery =
              nama.contains(_searchQuery) || nim.contains(_searchQuery);
          bool matchesFilter =
              _filterStatus == FilterStatus.all ||
              (_filterStatus == FilterStatus.tepat &&
                  status.contains('tepat')) ||
              (_filterStatus == FilterStatus.telat && status.contains('telat'));

          return matchesQuery && matchesFilter;
        }).toList();

        if (filteredList.isEmpty) {
          return Center(child: Text('Tidak ditemukan data absensi.'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredList.length > 5 ? 5 : filteredList.length,
          itemBuilder: (context, index) {
            final item = filteredList[index];
            return Card(
              color: Colors.white,
              elevation: 2,
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: darkBlue,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  item['nama'] ?? '-',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'NIM: ${item['nim'] ?? '-'}\n'
                  'Waktu: ${item['timestamp'] ?? '-'}\n'
                  'Status: ${item['status'] ?? '-'}',
                  style: TextStyle(fontSize: 13),
                ),
                trailing: Icon(
                  item['status'] == 'Tepat Waktu'
                      ? Icons.check_circle
                      : Icons.warning,
                  color: item['status'] == 'Tepat Waktu'
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRekapitulasiAbsensi() {
    // Jika tombol "Terlambat" dipilih, tampilkan semua data "Terlambat" tanpa filter tanggal
    if (_filterStatus == FilterStatus.telat) {
      List<Map<String, dynamic>> filtered = allAttendance.where((item) {
        final status = (item['status'] ?? '').toString().toLowerCase();
        return status == 'terlambat';
      }).toList();
      filtered.sort(
        (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
      );

      if (filtered.isEmpty) {
        return Center(
          child: Text(
            'Tidak ada data absensi terlambat.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return Card(
            color: Colors.white,
            elevation: 2,
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: darkBlue,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                item['nama'] ?? '-',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'NIM: ${item['nim'] ?? '-'}\n'
                'Waktu: ${item['timestamp'] ?? '-'}\n'
                'Status: ${item['status'] ?? '-'}',
                style: TextStyle(fontSize: 13),
              ),
              trailing: Icon(Icons.warning, color: Colors.orange),
            ),
          );
        },
      );
    }

    // Untuk "Semua" dan "Tepat Waktu", tetap butuh tanggal
    if (selectedDate == null) {
      return Center(
        child: Text(
          'Silakan pilih tanggal untuk melihat rekapitulasi.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    List<Map<String, dynamic>> filtered = [];
    if (allAttendance.isNotEmpty) {
      String filterDate =
          "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
      filtered = allAttendance.where((item) {
        final ts = item['timestamp'] ?? '';
        final status = (item['status'] ?? '').toString().toLowerCase();
        bool matchesFilter =
            _filterStatus == FilterStatus.all ||
            (_filterStatus == FilterStatus.tepat && status == 'tepat waktu');
        return ts.startsWith(filterDate) && matchesFilter;
      }).toList();
      filtered.sort(
        (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada data absensi pada tanggal ini.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return Card(
          color: Colors.white,
          elevation: 2,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: darkBlue,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              item['nama'] ?? '-',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'NIM: ${item['nim'] ?? '-'}\n'
              'Waktu: ${item['timestamp'] ?? '-'}\n'
              'Status: ${item['status'] ?? '-'}',
              style: TextStyle(fontSize: 13),
            ),
            trailing: Icon(
              item['status'] == 'Tepat Waktu'
                  ? Icons.check_circle
                  : Icons.warning,
              color: item['status'] == 'Tepat Waktu'
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
        );
      },
    );
  }
}
