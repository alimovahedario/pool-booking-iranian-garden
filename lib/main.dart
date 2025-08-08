import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'dart:io';

void main() {
  runApp(EstakhrApp());
}

class EstakhrApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'استخر باغ ایرانی',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [const Locale('fa', 'IR')],
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'IranSans',
      ),
      home: LoginPage(),
    );
  }
}

class Slot {
  final String id;
  final String label;
  Slot({required this.id, required this.label});
}

class Reservation {
  String block;
  String unit;
  Jalali date; // شمسی
  String slotLabel;
  String status; // pending/approved/rejected
  Reservation({
    required this.block,
    required this.unit,
    required this.date,
    required this.slotLabel,
    required this.status,
  });
  Map<String,dynamic> toMap(){
    return {
      'block': block,
      'unit': unit,
      'date': '${date.year}/${date.month.toString().padLeft(2,'0')}/${date.day.toString().padLeft(2,'0')}',
      'slot': slotLabel,
      'status': status,
    };
  }
}

class AppState extends ChangeNotifier {
  // slots are fixed: 11-13,14-16,17-19,20-22
  List<Slot> slots = [
    Slot(id: 's1', label: '11:00-13:00'),
    Slot(id: 's2', label: '14:00-16:00'),
    Slot(id: 's3', label: '17:00-19:00'),
    Slot(id: 's4', label: '20:00-22:00'),
  ];

  // reservations in-memory
  List<Reservation> reservations = [];

  void addReservation(Reservation r){
    reservations.add(r);
    notifyListeners();
  }

  void updateReservationStatus(int idx, String status){
    reservations[idx].status = status;
    notifyListeners();
  }

  List<Reservation> reservationsForDate(Jalali date){
    return reservations.where((r) => r.date.year==date.year && r.date.month==date.month && r.date.day==date.day).toList();
  }

  int approvedCountForUnitInMonth(String block, String unit, int year, int month){
    return reservations.where((r) => r.block==block && r.unit==unit && r.status=='approved' && r.date.year==year && r.date.month==month).length;
  }

  // export CSV with approved reservations and summary
  String exportCsvForMonth(int year, int month){
    List<List<String>> rows = [];
    rows.add(['بلوک','واحد','تاریخ (شمسی)','سانس','وضعیت']);
    for(var r in reservations){
      if(r.date.year==year && r.date.month==month && r.status=='approved'){
        rows.add([r.block, r.unit, '${r.date.year}/${r.date.month.toString().padLeft(2,'0')}/${r.date.day.toString().padLeft(2,'0')}', r.slotLabel, r.status]);
      }
    }
    // summary
    rows.add([]);
    rows.add(['بلوک','واحد','تعداد رزرو تایید شده']);
    Map<String,int> summary = {};
    for(var r in reservations){
      if(r.date.year==year && r.date.month==month && r.status=='approved'){
        String key='${r.block}-${r.unit}';
        summary[key] = (summary[key] ?? 0) + 1;
      }
    }
    var keys = summary.keys.toList();
    keys.sort();
    for(var k in keys){
      var parts = k.split('-');
      rows.add([parts[0], parts[1], summary[k].toString()]);
    }
    return const ListToCsvConverter().convert(rows);
  }
}

final appState = AppState();

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String selectedBlock = 'A';
  final unitController = TextEditingController();

  void goLogin(){
    String unit = unitController.text.trim();
    if(unit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('کد واحد را وارد کنید')));
      return;
    }
    String code = '${selectedBlock}${unit}';
    Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage(unitCode: code)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('استخر باغ ایرانی'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height:20),
            Icon(Icons.pool, size:80, color: Colors.green),
            SizedBox(height:12),
            Text('ورود با کد واحد', style: TextStyle(fontSize:18)),
            SizedBox(height:12),
            Row(
              children: [
                DropdownButton<String>(
                  value: selectedBlock,
                  items: ['A','B','C','D'].map((b)=>DropdownMenuItem(child: Text(b), value: b)).toList(),
                  onChanged: (v){ setState(()=>selectedBlock=v!); },
                ),
                SizedBox(width:12),
                Expanded(child: TextField(controller: unitController, decoration: InputDecoration(labelText: 'شماره واحد (مثال: 101)'))),
              ],
            ),
            SizedBox(height:20),
            ElevatedButton(onPressed: goLogin, child: Text('ورود')),
            SizedBox(height:12),
            TextButton(onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (_) => ManagerLoginPage()));
            }, child: Text('ورود مدیر'))
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String unitCode;
  HomePage({required this.unitCode});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Jalali tomorrow = Jalali.now().add(Duration(days:1));
  @override
  Widget build(BuildContext context) {
    String block = widget.unitCode.substring(0,1);
    String unit = widget.unitCode.substring(1);
    return Scaffold(
      appBar: AppBar(
        title: Text('سلام ${widget.unitCode}'),
        actions: [
          IconButton(onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (_) => MyReservationsPage(unitCode: widget.unitCode)));
          }, icon: Icon(Icons.list))
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text('سانس‌های موجود برای فردا: ${tomorrow.formatCompactDate()}', style: TextStyle(fontSize:16)),
            SizedBox(height:8),
            Expanded(
              child: ListView.builder(
                itemCount: appState.slots.length,
                itemBuilder: (c,i){
                  var slot = appState.slots[i];
                  // check if slot already reserved by someone for that date
                  var reserved = appState.reservationsForDate(tomorrow).where((r)=>r.slotLabel==slot.label && r.status=='approved').isNotEmpty;
                  var myRequestsCount = appState.reservations.where((r)=>r.block==block && r.unit==unit && r.date.year==tomorrow.year && r.date==null ? false : r.date.month==tomorrow.month && r.date.day==tomorrow.day).length;
                  bool canRequest = !reserved && myRequestsCount < 2;
                  return Card(
                    child: ListTile(
                      title: Text(slot.label),
                      subtitle: Text(reserved ? 'قبلاً رزرو شده' : 'آزاد'),
                      trailing: ElevatedButton(
                        onPressed: canRequest ? (){
                          // create pending reservation
                          var res = Reservation(block: block, unit: unit, date: tomorrow, slotLabel: slot.label, status: 'pending');
                          appState.addReservation(res);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('درخواست رزرو ثبت شد. منتظر تایید مدیر باشید.')));
                        } : null,
                        child: Text('رزرو'),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height:8),
            Text('توضیح: رزرو برای فردا امکان‌پذیر است. هر واحد تا ۲ نوبت مجاز است.'),
          ],
        ),
      ),
    );
  }
}

extension JalaliExt on Jalali {
  String formatCompactDate(){
    return '${this.year}/${this.month.toString().padLeft(2,'0')}/${this.day.toString().padLeft(2,'0')}';
  }
}

class MyReservationsPage extends StatefulWidget {
  final String unitCode;
  MyReservationsPage({required this.unitCode});
  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage> {
  @override
  Widget build(BuildContext context) {
    String block = widget.unitCode.substring(0,1);
    String unit = widget.unitCode.substring(1);
    var myRes = appState.reservations.where((r)=>r.block==block && r.unit==unit).toList();
    return Scaffold(
      appBar: AppBar(title: Text('رزروهای من')),
      body: ListView.builder(
        itemCount: myRes.length,
        itemBuilder: (c,i){
          var r = myRes[i];
          return ListTile(
            title: Text('${r.slotLabel} — ${r.date.formatCompactDate()}'),
            subtitle: Text('وضعیت: ${r.status}'),
          );
        },
      ),
    );
  }
}

class ManagerLoginPage extends StatefulWidget {
  @override
  State<ManagerLoginPage> createState() => _ManagerLoginPageState();
}

class _ManagerLoginPageState extends State<ManagerLoginPage> {
  final passCtrl = TextEditingController();
  void login(){
    if(passCtrl.text=='admin123'){
      Navigator.push(context, MaterialPageRoute(builder: (_) => ManagerPanelPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('رمز اشتباه است')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ورود مدیر'),
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(controller: passCtrl, decoration: InputDecoration(labelText: 'رمز مدیر')),
            SizedBox(height:12),
            ElevatedButton(onPressed: login, child: Text('ورود')),
          ],
        ),
      ),
    );
  }
}

class ManagerPanelPage extends StatefulWidget {
  @override
  State<ManagerPanelPage> createState() => _ManagerPanelPageState();
}

class _ManagerPanelPageState extends State<ManagerPanelPage> {
  Jalali tomorrow = Jalali.now().add(Duration(days:1));
  @override
  Widget build(BuildContext context) {
    var pending = appState.reservations.where((r)=>r.status=='pending').toList();
    return Scaffold(
      appBar: AppBar(title: Text('پنل مدیر')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text('درخواست‌های در انتظار تایید', style: TextStyle(fontSize:16)),
            Expanded(
              child: ListView.builder(
                itemCount: pending.length,
                itemBuilder: (c,i){
                  var r = pending[i];
                  return Card(
                    child: ListTile(
                      title: Text('${r.block}${r.unit} — ${r.slotLabel}'),
                      subtitle: Text('${r.date.formatCompactDate()}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(onPressed: (){
                          // approve if slot not already approved
                          bool slotTaken = appState.reservationsForDate(r.date).where((x)=>x.slotLabel==r.slotLabel && x.status=='approved').isNotEmpty;
                          if(slotTaken){
                            // reject and notify
                            appState.updateReservationStatus(appState.reservations.indexOf(r), 'rejected');
                            showDialog(context: context, builder: (_)=>AlertDialog(title: Text('رد شد'), content: Text('این سانس قبلاً رزرو شده است.'), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text('باشه'))]));
                          } else {
                            appState.updateReservationStatus(appState.reservations.indexOf(r), 'approved');
                            // notify (simple dialog)
                            showDialog(context: context, builder: (_)=>AlertDialog(title: Text('تایید'), content: Text('رزرو ${r.block}${r.unit} برای ${r.slotLabel} تایید شد.'), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text('باشه'))]));
                          }
                        }, icon: Icon(Icons.check, color: Colors.green)),
                        IconButton(onPressed: (){
                          appState.updateReservationStatus(appState.reservations.indexOf(r), 'rejected');
                          showDialog(context: context, builder: (_)=>AlertDialog(title: Text('رد شد'), content: Text('رزرو ${r.block}${r.unit} رد شد.'), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text('باشه'))]));
                        }, icon: Icon(Icons.close, color: Colors.red)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height:8),
            ElevatedButton(onPressed: (){
              // export CSV for current month
              var now = Jalali.now();
              String csv = appState.exportCsvForMonth(now.year, now.month);
              showDialog(context: context, builder: (_)=>AlertDialog(title: Text('گزارش CSV ماه جاری'), content: SingleChildScrollView(child: Text(csv)), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text('باشه'))]));
            }, child: Text('نمایش گزارش ماه جاری (CSV)')),
          ],
        ),
      ),
    );
  }
}
