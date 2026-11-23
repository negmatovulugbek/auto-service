// =========================================================
//  AUTO SERVICE — Usta ish hisob-kitobi ilovasi  (v3)
//  Menyular: Asosiy | Tahrirlash | Statistika
//
//  v3 yangiliklari:
//   ✅ Asosiy: mashina turlari bo'yicha qidiruv
//   ✅ To'lov: to'liq / qisman / qarz (chekda to'langan va qoldiq)
//   ✅ Chek: Telegram (rasm yoki matn) va boshqa ilovalarga ulashish
//   ✅ Tahrirlash > Xarajatlar: har bir mashina uchun zapchastlar ro'yxati,
//      jami narx, "To'landi" tugmasi (tasdiqlash bilan). Statistikaga ta'sir qilmaydi
//   ✅ Statistika > Qarzdorlar: qarzni qisman yoki to'liq to'lash
//   ✅ Zamonaviy dizayn + kunduzgi / tungi rejim
// =========================================================
import 'dart:convert';
import 'dart:math' show Random, min, max;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutoServiceApp());
}

// =========================================================
//  RANGLAR (kunduzgi / tungi)
// =========================================================
class AppPalette {
  final bool dark;
  final Color bg, surface, text, gray, light, divider, brand, g1, g2;
  final Color green, red, amber, field;
  const AppPalette({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.text,
    required this.gray,
    required this.light,
    required this.divider,
    required this.brand,
    required this.g1,
    required this.g2,
    required this.green,
    required this.red,
    required this.amber,
    required this.field,
  });

  static const lightP = AppPalette(
    dark: false,
    bg: Color(0xFFF3F5FA),
    surface: Colors.white,
    text: Color(0xFF1A2138),
    gray: Color(0xFF6B7280),
    light: Color(0xFF9CA3AF),
    divider: Color(0xFFE5E7EB),
    brand: Color(0xFF052859),
    g1: Color(0xFF052859),
    g2: Color(0xFF1B4A8F),
    green: Color(0xFF0FA67A),
    red: Color(0xFFE5484D),
    amber: Color(0xFFF59E0B),
    field: Color(0xFFF1F4F9),
  );

  static const darkP = AppPalette(
    dark: true,
    bg: Color(0xFF0B1220),
    surface: Color(0xFF151E32),
    text: Color(0xFFE8ECF4),
    gray: Color(0xFF9AA4B8),
    light: Color(0xFF6B7690),
    divider: Color(0xFF26314A),
    brand: Color(0xFF6AA7FF),
    g1: Color(0xFF0B2A5E),
    g2: Color(0xFF1B4A8F),
    green: Color(0xFF34D399),
    red: Color(0xFFF87171),
    amber: Color(0xFFFBBF24),
    field: Color(0xFF1C2740),
  );

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [g1, g2],
      );
}

extension PaletteX on BuildContext {
  AppPalette get c => Theme.of(this).brightness == Brightness.dark
      ? AppPalette.darkP
      : AppPalette.lightP;
}

const String som = "so'm";

// =========================================================
//  YORDAMCHI FUNKSIYALAR
// =========================================================
int _uidCounter = 0;
String uid() {
  _uidCounter += 1;
  final ts = DateTime.now().microsecondsSinceEpoch;
  final rnd = Random().nextInt(999999);
  return '${ts}_${_uidCounter}_$rnd';
}

String formatPrice(double v) {
  return v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );
}

double parseMoney(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return 0;
  return double.tryParse(d) ?? 0;
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String fmtDateTime(DateTime d) =>
    '${fmtDate(d)}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

void toast(BuildContext context, String msg, {Color? color}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String yes = 'Ha',
  String no = "Yo'q",
  Color? color,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: TextStyle(
              color: ctx.c.text, fontWeight: FontWeight.bold, fontSize: 18)),
      content: Text(message, style: TextStyle(color: ctx.c.gray)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: Text(no)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: filledStyle(color ?? ctx.c.brand),
          child: Text(yes),
        ),
      ],
    ),
  );
  return r ?? false;
}

ButtonStyle filledStyle(Color bg, {double vertical = 14}) =>
    FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: vertical, horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    );

BoxDecoration cardDeco(AppPalette c,
    {double r = 18, Color? border, Color? color}) {
  return BoxDecoration(
    color: color ?? c.surface,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(
        color: border ?? (c.dark ? c.divider : Colors.transparent)),
    boxShadow: c.dark
        ? null
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
  );
}

class MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final text = formatPrice(double.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// =========================================================
//  MODELLAR
// =========================================================
class WorkItem {
  String id, name;
  double price;
  WorkItem({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
  factory WorkItem.fromJson(Map<String, dynamic> j) => WorkItem(
        id: j['id'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
      );
}

class CarType {
  String id, name, icon;
  List<WorkItem> works;
  CarType({
    required this.id,
    required this.name,
    required this.icon,
    List<WorkItem>? works,
  }) : works = works ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'works': works.map((w) => w.toJson()).toList(),
      };

  factory CarType.fromJson(Map<String, dynamic> j) => CarType(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: (j['icon'] as String?) ?? '🚗',
        works: (j['works'] as List? ?? [])
            .map((w) => WorkItem.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}

class Payment {
  double amount;
  DateTime date;
  Payment({required this.amount, required this.date});

  Map<String, dynamic> toJson() =>
      {'amount': amount, 'date': date.toIso8601String()};
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
      );
}

class ServiceRecord {
  String id, carTypeName, carIcon;
  String customerName, customerPhone, carPlate;
  List<WorkItem> works;
  double total;
  List<Payment> payments;
  DateTime date;

  ServiceRecord({
    required this.id,
    required this.carTypeName,
    required this.carIcon,
    required this.customerName,
    required this.customerPhone,
    required this.carPlate,
    required this.works,
    required this.total,
    required this.payments,
    required this.date,
  });

  double get paid => payments.fold(0.0, (s, p) => s + p.amount);
  double get debt => max(total - paid, 0.0);
  bool get isDebt => debt > 0.5;

  String get receiptNo {
    final s = id.split('_').last;
    return '#${s.length > 6 ? s.substring(s.length - 6) : s.padLeft(6, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'carTypeName': carTypeName,
        'carIcon': carIcon,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'carPlate': carPlate,
        'works': works.map((w) => w.toJson()).toList(),
        'total': total,
        'payments': payments.map((p) => p.toJson()).toList(),
        'date': date.toIso8601String(),
      };

  factory ServiceRecord.fromJson(Map<String, dynamic> j) {
    final total = (j['total'] as num).toDouble();
    final date = DateTime.parse(j['date'] as String);
    List<Payment> pays;
    if (j['payments'] != null) {
      pays = (j['payments'] as List)
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // eski versiya: faqat "paid" maydoni bor edi
      final paid = (j['paid'] as num?)?.toDouble() ?? total;
      pays = paid > 0 ? [Payment(amount: paid, date: date)] : [];
    }
    return ServiceRecord(
      id: j['id'] as String,
      carTypeName: j['carTypeName'] as String,
      carIcon: (j['carIcon'] as String?) ?? '🚗',
      customerName: (j['customerName'] as String?) ?? '',
      customerPhone: (j['customerPhone'] as String?) ?? '',
      carPlate: (j['carPlate'] as String?) ?? '',
      works: (j['works'] as List? ?? [])
          .map((w) => WorkItem.fromJson(w as Map<String, dynamic>))
          .toList(),
      total: total,
      payments: pays,
      date: date,
    );
  }
}

/// Xarajatlar bo'limi: har bir mashina uchun zapchastlar ro'yxati.
/// Bu "izoh" kabi alohida saqlanadi — Statistika / qarzdorlarga qo'shilmaydi.
class ExpenseGroup {
  String id, carName, plate;
  List<WorkItem> items;
  bool paid;
  DateTime date;

  ExpenseGroup({
    required this.id,
    required this.carName,
    this.plate = '',
    List<WorkItem>? items,
    this.paid = false,
    required this.date,
  }) : items = items ?? [];

  double get total => items.fold(0.0, (s, i) => s + i.price);

  Map<String, dynamic> toJson() => {
        'id': id,
        'carName': carName,
        'plate': plate,
        'items': items.map((i) => i.toJson()).toList(),
        'paid': paid,
        'date': date.toIso8601String(),
      };

  factory ExpenseGroup.fromJson(Map<String, dynamic> j) => ExpenseGroup(
        id: j['id'] as String,
        carName: j['carName'] as String,
        plate: (j['plate'] as String?) ?? '',
        items: (j['items'] as List? ?? [])
            .map((e) => WorkItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        paid: (j['paid'] as bool?) ?? false,
        date: DateTime.parse(j['date'] as String),
      );
}

class UstaInfo {
  String name, phone;
  UstaInfo({this.name = '', this.phone = ''});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
  factory UstaInfo.fromJson(Map<String, dynamic> j) => UstaInfo(
        name: (j['name'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
      );
}

// =========================================================
//  SAQLASH (SharedPreferences)
// =========================================================
class Storage {
  static const _carsKey = 'auto_cars_v2';
  static const _recordsKey = 'auto_records_v2';
  static const _groupsKey = 'auto_exp_groups_v1';
  static const _ustaKey = 'auto_usta_v1';
  static const _seededKey = 'auto_seeded_v2';
  static const _darkKey = 'auto_dark_v1';

  static Future<List<T>> _list<T>(
      String key, T Function(Map<String, dynamic>) f) async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(key);
    if (s == null) return <T>[];
    return (jsonDecode(s) as List)
        .map((e) => f(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _put(String key, List<Map<String, dynamic>> v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(key, jsonEncode(v));
  }

  static Future<List<CarType>> loadCars() => _list(_carsKey, CarType.fromJson);
  static Future<void> saveCars(List<CarType> v) =>
      _put(_carsKey, v.map((e) => e.toJson()).toList());

  static Future<List<ServiceRecord>> loadRecords() =>
      _list(_recordsKey, ServiceRecord.fromJson);
  static Future<void> saveRecords(List<ServiceRecord> v) =>
      _put(_recordsKey, v.map((e) => e.toJson()).toList());

  static Future<List<ExpenseGroup>> loadGroups() =>
      _list(_groupsKey, ExpenseGroup.fromJson);
  static Future<void> saveGroups(List<ExpenseGroup> v) =>
      _put(_groupsKey, v.map((e) => e.toJson()).toList());

  static Future<UstaInfo> loadUsta() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_ustaKey);
    if (s == null) return UstaInfo();
    return UstaInfo.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  static Future<void> saveUsta(UstaInfo u) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_ustaKey, jsonEncode(u.toJson()));
  }

  static Future<bool> isSeeded() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_seededKey) ?? false;
  }

  static Future<void> markSeeded() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_seededKey, true);
  }

  static Future<bool> loadDark() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_darkKey) ?? false;
  }

  static Future<void> saveDark(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_darkKey, v);
  }
}

// =========================================================
//  APP STATE
// =========================================================
class AppState extends ChangeNotifier {
  List<CarType> cars = [];
  List<ServiceRecord> records = [];
  List<ExpenseGroup> groups = [];
  UstaInfo usta = UstaInfo();
  bool dark = false;
  bool _loading = true;
  bool get isLoading => _loading;

  AppState() {
    _load();
  }

  Future<void> _load() async {
    cars = await Storage.loadCars();
    records = await Storage.loadRecords();
    groups = await Storage.loadGroups();
    usta = await Storage.loadUsta();
    dark = await Storage.loadDark();
    if (cars.isEmpty && !await Storage.isSeeded()) {
      _seedDefaults();
    }
    _loading = false;
    notifyListeners();
  }

  void _seedDefaults() {
    cars = [
      CarType(id: uid(), name: 'Yengil avtomobil', icon: '🚗', works: [
        WorkItem(id: uid(), name: 'Moy almashtirish', price: 120000),
        WorkItem(id: uid(), name: 'Filtr almashtirish', price: 80000),
        WorkItem(id: uid(), name: 'Tormoz balandligi', price: 50000),
        WorkItem(id: uid(), name: 'Tormoz xodasi', price: 150000),
      ]),
      CarType(id: uid(), name: 'Yuk mashinasi', icon: '🚚', works: [
        WorkItem(id: uid(), name: 'Moy almashtirish', price: 250000),
        WorkItem(id: uid(), name: 'Tormoz xodasi', price: 180000),
      ]),
      CarType(id: uid(), name: 'Motosikl', icon: '🏍️', works: [
        WorkItem(id: uid(), name: 'Moy almashtirish', price: 60000),
        WorkItem(id: uid(), name: 'Zanjir sozlash', price: 40000),
      ]),
    ];
    Storage.saveCars(cars);
    Storage.markSeeded();
  }

  // ---------- saqlash ----------
  Future<void> saveCars() async {
    await Storage.saveCars(cars);
    notifyListeners();
  }

  Future<void> saveRecords() async {
    await Storage.saveRecords(records);
    notifyListeners();
  }

  Future<void> saveGroups() async {
    await Storage.saveGroups(groups);
    notifyListeners();
  }

  // ---------- Cars ----------
  Future<void> addCar(CarType c) {
    cars.add(c);
    return saveCars();
  }

  Future<void> deleteCar(String id) {
    cars.removeWhere((e) => e.id == id);
    return saveCars();
  }

  // ---------- Records ----------
  Future<void> addRecord(ServiceRecord r) {
    records.insert(0, r);
    return saveRecords();
  }

  Future<void> deleteRecord(String id) {
    records.removeWhere((e) => e.id == id);
    return saveRecords();
  }

  Future<void> addPayment(ServiceRecord r, double amount) {
    r.payments.add(Payment(amount: amount, date: DateTime.now()));
    return saveRecords();
  }

  // ---------- Expense groups ----------
  Future<void> addGroup(ExpenseGroup g) {
    groups.insert(0, g);
    return saveGroups();
  }

  Future<void> deleteGroup(String id) {
    groups.removeWhere((e) => e.id == id);
    return saveGroups();
  }

  // ---------- Usta / Tema ----------
  Future<void> saveUsta(UstaInfo u) async {
    usta = u;
    await Storage.saveUsta(u);
    notifyListeners();
  }

  Future<void> toggleDark() async {
    dark = !dark;
    notifyListeners();
    await Storage.saveDark(dark);
  }
}

// =========================================================
//  ROOT APP
// =========================================================
ThemeData _buildTheme(Brightness b) {
  final p = b == Brightness.dark ? AppPalette.darkP : AppPalette.lightP;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF052859),
      brightness: b,
      primary: p.brand,
    ),
    fontFamily: 'Roboto',
  );
}

class AutoServiceApp extends StatefulWidget {
  const AutoServiceApp({super.key});
  @override
  State<AutoServiceApp> createState() => _AutoServiceAppState();
}

class _AutoServiceAppState extends State<AutoServiceApp> {
  final AppState _state = AppState();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) => MaterialApp(
        title: 'Auto Service',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: _state.dark ? ThemeMode.dark : ThemeMode.light,
        home: SplashScreen(state: _state),
      ),
    );
  }
}

// =========================================================
//  SPLASH
// =========================================================
class SplashScreen extends StatefulWidget {
  final AppState state;
  const SplashScreen({super.key, required this.state});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _c.forward();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainScreen(state: widget.state)),
        );
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: c.gradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scale,
                child: FadeTransition(
                  opacity: _c,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.build_circle,
                        size: 70, color: Color(0xFF052859)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _c,
                child: const Text('Auto Service',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    )),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _c,
                child: const Text('Usta ish hisob-kitobi',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
//  UMUMIY WIDGETLAR
// =========================================================
class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool back;
  final List<Widget> actions;
  const HeaderBar({
    super.key,
    required this.title,
    this.back = false,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        gradient: c.gradient,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: c.g1.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              if (back)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(left: 10, right: 8),
                  child: Icon(Icons.build_circle_rounded,
                      color: Colors.white, size: 28),
                ),
              Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> mainActions(BuildContext context, AppState s) => [
      IconButton(
        tooltip: s.dark ? 'Kunduzgi rejim' : 'Tungi rejim',
        icon: Icon(
          s.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: Colors.white,
        ),
        onPressed: s.toggleDark,
      ),
      IconButton(
        tooltip: "Usta ma'lumotlari",
        icon: const Icon(Icons.person_rounded, color: Colors.white),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => UstaDialog(state: s),
        ),
      ),
    ];

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: c.brand.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: c.brand),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.text)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.gray, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextCapitalization caps;
  final List<TextInputFormatter>? formatters;
  final String? suffix;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  const LabeledField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.icon,
    this.keyboardType,
    this.caps = TextCapitalization.none,
    this.formatters,
    this.suffix,
    this.autofocus = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.gray)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: caps,
          autofocus: autofocus,
          onChanged: onChanged,
          style: TextStyle(color: c.text),
          inputFormatters: <TextInputFormatter>[
            if (caps == TextCapitalization.characters)
              UpperCaseTextFormatter(),
            ...?formatters,
          ],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.light),
            filled: true,
            fillColor: c.field,
            suffixText: suffix,
            suffixStyle: TextStyle(color: c.gray, fontSize: 13),
            prefixIcon:
                icon == null ? null : Icon(icon, color: c.brand, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, v, __) => TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: c.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.light, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: c.gray, size: 22),
          suffixIcon: v.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: c.gray),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: c.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: c.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: c.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: c.brand, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class NotFoundBox extends StatelessWidget {
  final String text;
  const NotFoundBox({super.key, this.text = 'Hech narsa topilmadi'});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: cardDeco(c, r: 16),
      child: Center(
        child: Text(text, style: TextStyle(color: c.gray)),
      ),
    );
  }
}

// =========================================================
//  ASOSIY EKRAN (Bottom nav)
// =========================================================
class MainScreen extends StatefulWidget {
  final AppState state;
  const MainScreen({super.key, required this.state});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        if (s.isLoading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: context.c.brand),
            ),
          );
        }
        final screens = [
          AsosiyScreen(state: s),
          TahrirlashScreen(state: s),
          StatistikaScreen(state: s),
        ];
        return Scaffold(
          extendBody: true,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: screens[_index],
            ),
          ),
          bottomNavigationBar: CustomBottomNav(
            index: _index,
            onChanged: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }
}

class CustomBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const CustomBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
  });

  static const _items = [
    [Icons.home_rounded, 'Asosiy'],
    [Icons.edit_rounded, 'Tahrirlash'],
    [Icons.bar_chart_rounded, 'Statistika'],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: c.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(c.dark ? 0.4 : 0.1),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final active = i == index;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    gradient: active ? c.gradient : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: c.g2.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_items[i][0] as IconData,
                          size: 22,
                          color: active ? Colors.white : c.gray),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: active
                            ? Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(_items[i][1] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    )),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// =========================================================
//  ASOSIY SCREEN — Mashina tanlash (qidiruv bilan)
// =========================================================
class AsosiyScreen extends StatefulWidget {
  final AppState state;
  const AsosiyScreen({super.key, required this.state});
  @override
  State<AsosiyScreen> createState() => _AsosiyScreenState();
}

class _AsosiyScreenState extends State<AsosiyScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CarType> get _cars {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return widget.state.cars;
    return widget.state.cars
        .where((car) =>
            car.name.toLowerCase().contains(q) ||
            car.works.any((w) => w.name.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = context.c;
    final cars = _cars;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: HeaderBar(title: 'Asosiy', actions: mainActions(context, s)),
      body: s.cars.isEmpty
          ? const EmptyState(
              icon: Icons.directions_car_outlined,
              title: "Mashina turlari yo'q",
              subtitle:
                  "Tahrirlash bo'limiga o'tib mashina turlarini qo'shing",
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              children: [
                Text('Mashina turini tanlang',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
                const SizedBox(height: 12),
                SearchField(
                  controller: _search,
                  hint: 'Qidirish: masalan Nexia...',
                  onChanged: (v) => setState(() => _q = v),
                ),
                const SizedBox(height: 14),
                if (cars.isEmpty)
                  const NotFoundBox(text: 'Bunday mashina turi topilmadi')
                else
                  ...cars.map((car) => CarCard(car: car, state: s)),
                if (s.records.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("So'nggi ishlar",
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      Text('${s.records.length} ta jami',
                          style: TextStyle(color: c.gray, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...s.records
                      .take(10)
                      .map((r) => RecordTile(record: r, state: s)),
                ],
              ],
            ),
    );
  }
}

class CarCard extends StatelessWidget {
  final CarType car;
  final AppState state;
  const CarCard({super.key, required this.car, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: cardDeco(c),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkSelectionScreen(car: car, state: state),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: c.brand.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                        child: Text(car.icon,
                            style: const TextStyle(fontSize: 30))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(car.name,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.text)),
                        const SizedBox(height: 4),
                        Text('${car.works.length} ta ish turi mavjud',
                            style: TextStyle(fontSize: 13, color: c.gray)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.light, size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecordTile extends StatelessWidget {
  final ServiceRecord record;
  final AppState state;
  final bool showWorks;
  const RecordTile({
    super.key,
    required this.record,
    required this.state,
    this.showWorks = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = record;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(r.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => confirmDialog(
          context,
          title: "O'chirish",
          message: "Bu yozuv o'chirilsinmi?",
          yes: "O'chirish",
          no: 'Bekor qilish',
          color: c.red,
        ),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: c.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) => state.deleteRecord(r.id),
        child: Container(
          decoration: cardDeco(c,
              r: 16, border: r.isDebt ? c.red.withOpacity(0.4) : null),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptScreen(state: state, record: r),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c.brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                          child: Text(r.carIcon,
                              style: const TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  r.customerName.isEmpty
                                      ? r.carTypeName
                                      : r.customerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: c.text,
                                      fontSize: 14),
                                ),
                              ),
                              if (r.isDebt) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: c.red,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('QARZ',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              r.carTypeName,
                              if (r.carPlate.isNotEmpty) r.carPlate,
                              showWorks ? fmtDateTime(r.date) : fmtDate(r.date),
                            ].join(' • '),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.gray),
                          ),
                          if (showWorks && r.works.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              r.works.map((w) => w.name).join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: c.light),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatPrice(r.total),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: c.text,
                                fontSize: 15)),
                        Text(som,
                            style: TextStyle(fontSize: 11, color: c.gray)),
                        const SizedBox(height: 2),
                        if (r.isDebt)
                          Text('−${formatPrice(r.debt)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: c.red,
                                  fontWeight: FontWeight.w700))
                        else
                          Text("✓ to'langan",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: c.green,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
//  WORK SELECTION — ish tanlash + mijoz + to'lov
// =========================================================
class WorkSelectionScreen extends StatefulWidget {
  final CarType car;
  final AppState state;
  const WorkSelectionScreen(
      {super.key, required this.car, required this.state});
  @override
  State<WorkSelectionScreen> createState() => _WorkSelectionScreenState();
}

class _WorkSelectionScreenState extends State<WorkSelectionScreen> {
  final Set<String> _selected = {};
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _workSearch = TextEditingController();
  String _wq = '';
  bool _showCustomer = false;
  int _mode = 0; // 0 = to'liq, 1 = qisman, 2 = qarz (to'lanmadi)

  List<WorkItem> get _visibleWorks {
    final q = _wq.trim().toLowerCase();
    if (q.isEmpty) return widget.car.works;
    return widget.car.works
        .where((w) => w.name.toLowerCase().contains(q))
        .toList();
  }

  double get _total => widget.car.works
      .where((w) => _selected.contains(w.id))
      .fold(0.0, (s, w) => s + w.price);

  double get _paid {
    if (_mode == 0) return _total;
    if (_mode == 2) return 0;
    return min(max(parseMoney(_paidCtrl.text), 0.0), _total);
  }

  double get _remaining => _total - _paid;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    _paidCtrl.dispose();
    _workSearch.dispose();
    super.dispose();
  }

  void _setMode(int m) {
    setState(() {
      _mode = m;
      if (m != 0) _showCustomer = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final car = widget.car;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: HeaderBar(title: '${car.icon}  ${car.name}', back: true),
      body: car.works.isEmpty
          ? const EmptyState(
              icon: Icons.build_outlined,
              title: "Ish turlari yo'q",
              subtitle: "Tahrirlash bo'limida ushbu mashinaga ish qo'shing",
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                Row(
                  children: [
                    Text('Ishni tanlang',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                    const Spacer(),
                    Text('${_selected.length} / ${car.works.length}',
                        style: TextStyle(
                            color: c.brand, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                SearchField(
                  controller: _workSearch,
                  hint: 'Ishni qidirish...',
                  onChanged: (v) => setState(() => _wq = v),
                ),
                const SizedBox(height: 12),
                if (_visibleWorks.isEmpty)
                  const NotFoundBox(text: 'Bunday ish topilmadi'),
                ..._visibleWorks.map((w) {
                  final sel = _selected.contains(w.id);
                  return WorkCheckTile(
                    key: ValueKey(w.id),
                    work: w,
                    selected: sel,
                    onToggle: () => setState(() {
                      if (sel) {
                        _selected.remove(w.id);
                      } else {
                        _selected.add(w.id);
                      }
                    }),
                  );
                }),
                const SizedBox(height: 8),
                _customerSection(c),
                if (_selected.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _paymentCard(c),
                ],
              ],
            ),
      bottomNavigationBar: _selected.isEmpty ? null : _bottomBar(c),
    );
  }

  Widget _customerSection(AppPalette c) {
    if (!_showCustomer) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _showCustomer = true),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.brand.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.brand.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.person_add_alt_rounded, color: c.brand, size: 20),
              const SizedBox(width: 10),
              Text("Mijoz ma'lumotini qo'shish",
                  style: TextStyle(
                      color: c.brand,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(c, r: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, color: c.brand, size: 18),
              const SizedBox(width: 6),
              Text("Mijoz ma'lumoti",
                  style: TextStyle(
                      color: c.brand,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (_mode == 0 ? c.green : c.red).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_mode == 0 ? 'Ixtiyoriy' : 'Qarz uchun kerak',
                    style: TextStyle(
                        color: _mode == 0 ? c.green : c.red, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Mijoz ismi',
            controller: _nameCtrl,
            hint: 'Ism Familiya',
            icon: Icons.person_outline_rounded,
            caps: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          LabeledField(
            label: 'Telefon',
            controller: _phoneCtrl,
            hint: '+998 90 123 45 67',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          LabeledField(
            label: 'Mashina raqami',
            controller: _plateCtrl,
            hint: '01A123BC',
            icon: Icons.directions_car_rounded,
            caps: TextCapitalization.characters,
          ),
        ],
      ),
    );
  }

  Widget _modeChip(AppPalette c, String label, IconData icon, int m, Color col) {
    final active = _mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setMode(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? col : c.field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? col : c.divider),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : c.gray),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : c.gray)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentCard(AppPalette c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(c, r: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_rounded, color: c.brand, size: 18),
              const SizedBox(width: 6),
              Text("To'lov holati",
                  style: TextStyle(
                      color: c.brand,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _modeChip(c, "To'liq", Icons.check_circle_rounded, 0, c.green),
              const SizedBox(width: 8),
              _modeChip(c, 'Qisman', Icons.timelapse_rounded, 1, c.amber),
              const SizedBox(width: 8),
              _modeChip(c, "To'lanmadi", Icons.schedule_rounded, 2, c.red),
            ],
          ),
          if (_mode == 1) ...[
            const SizedBox(height: 14),
            LabeledField(
              label: "Hozir to'langan summa",
              controller: _paidCtrl,
              hint: '0',
              icon: Icons.payments_outlined,
              suffix: som,
              keyboardType: TextInputType.number,
              formatters: [MoneyFormatter()],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              "Qolgan summa qarz sifatida yoziladi: ${formatPrice(_remaining)} $som",
              style: TextStyle(
                  color: c.red, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
          if (_mode == 2) ...[
            const SizedBox(height: 12),
            Text("Mijoz hozircha to'lamadi — butun summa qarzga yoziladi.",
                style: TextStyle(color: c.gray, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar(AppPalette c) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: c.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(c.dark ? 0.4 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Jami:', style: TextStyle(color: c.gray, fontSize: 14)),
                Text('${formatPrice(_total)} $som',
                    style: TextStyle(
                        color: c.brand,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            if (_mode != 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("To'lanadi:",
                      style: TextStyle(
                          color: c.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('${formatPrice(_paid)} $som',
                      style: TextStyle(
                          color: c.green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Qarz:',
                      style: TextStyle(
                          color: c.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('${formatPrice(_remaining)} $som',
                      style: TextStyle(
                          color: c.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Saqlash va chek chiqarish',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: filledStyle(c.g2),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_mode == 1) {
      final v = parseMoney(_paidCtrl.text);
      if (v <= 0 || v >= _total) {
        toast(context,
            "Qisman to'lov 0 dan katta va jami summadan kichik bo'lishi kerak");
        return;
      }
    }
    if (_mode != 0 &&
        _nameCtrl.text.trim().isEmpty &&
        _phoneCtrl.text.trim().isEmpty) {
      setState(() => _showCustomer = true);
      toast(context, 'Qarz uchun mijoz ismi yoki telefonini kiriting');
      return;
    }
    final now = DateTime.now();
    final paid = _paid;
    final rec = ServiceRecord(
      id: uid(),
      carTypeName: widget.car.name,
      carIcon: widget.car.icon,
      customerName: _nameCtrl.text.trim(),
      customerPhone: _phoneCtrl.text.trim(),
      carPlate: _plateCtrl.text.trim().toUpperCase(),
      works: widget.car.works.where((w) => _selected.contains(w.id)).toList(),
      total: _total,
      payments: paid > 0 ? [Payment(amount: paid, date: now)] : [],
      date: now,
    );
    widget.state.addRecord(rec);
    toast(
      context,
      rec.isDebt
          ? 'Saqlandi. Qarz: ${formatPrice(rec.debt)} $som'
          : "Saqlandi: ${formatPrice(rec.total)} $som (to'liq to'langan)",
      color: rec.isDebt ? context.c.amber : context.c.green,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(state: widget.state, record: rec),
      ),
    );
  }
}

class WorkCheckTile extends StatelessWidget {
  final WorkItem work;
  final bool selected;
  final VoidCallback onToggle;
  const WorkCheckTile({
    super.key,
    required this.work,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? c.g2 : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? c.g2 : c.divider, width: 1.5),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.g2.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  border: Border.all(
                      color: selected ? Colors.white : c.light, width: 2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 18, color: c.g2)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(work.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : c.text,
                    )),
              ),
              Text('${formatPrice(work.price)} $som',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : c.green,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
//  RECEIPT SCREEN — Chek + Telegram / ulashish + qarz to'lash
// =========================================================
class ReceiptScreen extends StatefulWidget {
  final AppState state;
  final ServiceRecord record;
  const ReceiptScreen({super.key, required this.state, required this.record});
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _busy = false;

  String _ustaName() => widget.state.usta.name.trim().isEmpty
      ? 'Auto Service'
      : widget.state.usta.name.trim();

  /// Chekni rasm qilib ulashish (ro'yxatdan Telegram'ni tanlab, kerakli odamga yuboriladi)
  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final boundary = _receiptKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'chek_${widget.record.id}.png')],
        text: 'Chek ${widget.record.receiptNo} — ${_ustaName()}',
      );
    } catch (e) {
      if (mounted) {
        toast(context,
            "Bu brauzer rasm ulashishni qo'llamaydi. «Matn» orqali yuboring.",
            color: context.c.red);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _receiptText() {
    final r = widget.record;
    final u = widget.state.usta;
    final b = StringBuffer();
    b.writeln('🧾 ${_ustaName()}');
    if (u.phone.trim().isNotEmpty) b.writeln('☎️ ${u.phone.trim()}');
    b.writeln('Chek ${r.receiptNo} • ${fmtDateTime(r.date)}');
    b.writeln('');
    b.writeln('${r.carIcon} ${r.carTypeName}'
        '${r.carPlate.isNotEmpty ? ' (${r.carPlate})' : ''}');
    if (r.customerName.isNotEmpty) b.writeln('Mijoz: ${r.customerName}');
    b.writeln('');
    b.writeln('Bajarilgan ishlar:');
    for (var i = 0; i < r.works.length; i++) {
      b.writeln('${i + 1}. ${r.works[i].name} — ${formatPrice(r.works[i].price)}');
    }
    b.writeln('');
    b.writeln('JAMI: ${formatPrice(r.total)} $som');
    b.writeln("To'langan: ${formatPrice(r.paid)} $som");
    if (r.isDebt) {
      b.writeln('QOLDIQ (QARZ): ${formatPrice(r.debt)} $som');
    } else {
      b.writeln("✅ To'liq to'langan");
    }
    b.writeln('');
    b.writeln("Rahmat! Sog'-salomat bo'ling! 🙏");
    return b.toString();
  }

  /// Telegram'ni ochib, matnni kerakli odamga yuborish
  Future<void> _shareTelegramText() async {
    final text = _receiptText();
    // Zaxira: chek matni avval nusxa olinadi (Telegram matnni olib kelmasa,
    // chatda "Qo'yish" (Paste) qilish mumkin)
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
    try {
      // Matn "url" parametri orqali uzatiladi — Telegram buni ishonchli qabul qiladi
      final ok = await launchUrl(
        Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication,
      );
      if (ok) {
        if (mounted) {
          toast(context,
              "Chek matni nusxalandi. Telegram'da bo'sh bo'lsa, «Qo'yish» ni bosing");
        }
        return;
      }
    } catch (_) {}
    // Telegram ochilmasa — umumiy ulashish oynasi
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final r = widget.record;
        return Scaffold(
          backgroundColor: c.bg,
          appBar: HeaderBar(
            title: 'Chek',
            back: true,
            actions: [
              IconButton(
                tooltip: 'Ulashish',
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: _busy ? null : _shareImage,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: RepaintBoundary(
                      key: _receiptKey,
                      child: _card(r),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (r.isDebt) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) =>
                            PayDebtDialog(state: widget.state, record: r),
                      ),
                      icon: const Icon(Icons.add_card_rounded),
                      label: const Text("To'lov qabul qilish",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      style: filledStyle(c.green),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _shareImage,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                        _busy ? 'Tayyorlanmoqda...' : 'Chekni yuborish (rasm)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    style: filledStyle(c.g2),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _shareTelegramText,
                    icon: const Icon(Icons.telegram_rounded),
                    label: const Text('Telegramga matn qilib yuborish',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.brand,
                      side: BorderSide(color: c.brand.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.check_rounded, color: c.green),
                  label: Text('Tugatish', style: TextStyle(color: c.green)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Chek har doim oq fonda (rasm sifatida chiroyli chiqishi uchun)
  Widget _card(ServiceRecord r) {
    const p = AppPalette.lightP;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(gradient: p.gradient),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.build_circle,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(_ustaName(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ],
                ),
                if (widget.state.usta.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(widget.state.usta.phone.trim(),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmtDateTime(r.date),
                        style: TextStyle(color: p.gray, fontSize: 12)),
                    Text(r.receiptNo,
                        style: TextStyle(color: p.gray, fontSize: 12)),
                  ],
                ),
                Divider(height: 22, color: p.divider),
                Row(
                  children: [
                    Text(r.carIcon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(r.carTypeName,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: p.text,
                              fontSize: 15)),
                    ),
                  ],
                ),
                if (r.customerName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _row('Mijoz', r.customerName),
                ],
                if (r.carPlate.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _row('Raqam', r.carPlate),
                ],
                if (r.customerPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _row('Telefon', r.customerPhone),
                ],
                Divider(height: 22, color: p.divider),
                Text('Bajarilgan ishlar',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.text)),
                const SizedBox(height: 8),
                ...r.works.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.key + 1}. ',
                              style: TextStyle(
                                  color: p.gray,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Expanded(
                            child: Text(e.value.name,
                                style:
                                    TextStyle(fontSize: 14, color: p.text)),
                          ),
                          Text(formatPrice(e.value.price),
                              style: TextStyle(
                                  fontSize: 14,
                                  color: p.text,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                Divider(height: 22, color: p.divider),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('JAMI:',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: p.brand)),
                    Text('${formatPrice(r.total)} $som',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: p.brand)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (r.isDebt ? p.red : p.green).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: (r.isDebt ? p.red : p.green).withOpacity(0.35)),
                  ),
                  child: Column(
                    children: [
                      _row("To'langan", '${formatPrice(r.paid)} $som',
                          color: p.green, bold: true),
                      if (r.payments.length > 1)
                        ...r.payments.map((x) => Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('  ${fmtDate(x.date)}',
                                      style: TextStyle(
                                          fontSize: 11, color: p.gray)),
                                  Text(formatPrice(x.amount),
                                      style: TextStyle(
                                          fontSize: 11, color: p.gray)),
                                ],
                              ),
                            )),
                      const SizedBox(height: 8),
                      if (r.isDebt)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('QOLDIQ (QARZ)',
                                style: TextStyle(
                                    color: p.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Text('${formatPrice(r.debt)} $som',
                                style: TextStyle(
                                    color: p.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Holati',
                                style:
                                    TextStyle(color: p.gray, fontSize: 13)),
                            Text("✓ To'liq to'langan",
                                style: TextStyle(
                                    color: p.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text("Rahmat! Sog'-salomat bo'ling! 🙏",
                      style: TextStyle(color: p.gray, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    const p = AppPalette.lightP;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: p.gray, fontSize: 13)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: color ?? p.text,
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ),
      ],
    );
  }
}

// =========================================================
//  QARZNI TO'LASH DIALOGI (qisman yoki to'liq)
// =========================================================
class PayDebtDialog extends StatefulWidget {
  final AppState state;
  final ServiceRecord record;
  const PayDebtDialog({super.key, required this.state, required this.record});
  @override
  State<PayDebtDialog> createState() => _PayDebtDialogState();
}

class _PayDebtDialogState extends State<PayDebtDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _line(AppPalette c, String l, String v, {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: TextStyle(color: c.gray, fontSize: 13)),
            Text(v,
                style: TextStyle(
                    color: color ?? c.text,
                    fontSize: 13.5,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = widget.record;
    final amount = parseMoney(_ctrl.text);
    final left = max(r.debt - amount, 0.0);
    final who = r.customerName.isNotEmpty
        ? r.customerName
        : (r.customerPhone.isNotEmpty ? r.customerPhone : r.carTypeName);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.add_card_rounded, color: c.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Qarzni to'lash",
                style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.carIcon} $who',
                style: TextStyle(
                    color: c.text, fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            _line(c, 'Jami', '${formatPrice(r.total)} $som'),
            _line(c, "To'langan", '${formatPrice(r.paid)} $som',
                color: c.green),
            _line(c, 'Qarz', '${formatPrice(r.debt)} $som',
                color: c.red, bold: true),
            const SizedBox(height: 10),
            LabeledField(
              label: "Hozir to'lanayotgan summa",
              controller: _ctrl,
              hint: '0',
              icon: Icons.payments_outlined,
              suffix: som,
              autofocus: true,
              keyboardType: TextInputType.number,
              formatters: [MoneyFormatter()],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text("Hammasi (${formatPrice(r.debt)})"),
                  onPressed: () => setState(() {
                    _ctrl.text = formatPrice(r.debt);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (left > 0 ? c.red : c.green).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Qoladigan qarz:',
                      style: TextStyle(
                          color: left > 0 ? c.red : c.green, fontSize: 13)),
                  Text(
                      left > 0
                          ? '${formatPrice(left)} $som'
                          : "Qarz yopiladi ✓",
                      style: TextStyle(
                          color: left > 0 ? c.red : c.green,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: _save,
          style: filledStyle(c.green, vertical: 12),
          child: const Text("To'lovni saqlash"),
        ),
      ],
    );
  }

  void _save() {
    final r = widget.record;
    final amount = parseMoney(_ctrl.text);
    if (amount <= 0) {
      toast(context, "To'lov summasini kiriting");
      return;
    }
    if (amount > r.debt + 0.5) {
      toast(context, 'Summa qarzdan oshib ketdi (${formatPrice(r.debt)} $som)');
      return;
    }
    widget.state.addPayment(r, amount);
    final left = max(r.debt, 0.0);
    toast(
      context,
      left > 0.5
          ? "Qabul qilindi. Qolgan qarz: ${formatPrice(left)} $som"
          : "Qarz to'liq yopildi ✓",
      color: context.c.green,
    );
    Navigator.pop(context);
  }
}

// =========================================================
//  TAHRIRLASH SCREEN — Mashinalar + Xarajatlar
// =========================================================
class TahrirlashScreen extends StatefulWidget {
  final AppState state;
  const TahrirlashScreen({super.key, required this.state});
  @override
  State<TahrirlashScreen> createState() => _TahrirlashScreenState();
}

class _TahrirlashScreenState extends State<TahrirlashScreen> {
  int _tab = 0; // 0 = mashinalar, 1 = xarajatlar

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: HeaderBar(title: 'Tahrirlash', actions: mainActions(context, s)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: cardDeco(c, r: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: 'Mashinalar',
                      icon: Icons.directions_car_rounded,
                      active: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                  ),
                  Expanded(
                    child: _SegmentButton(
                      label: 'Xarajatlar',
                      icon: Icons.receipt_long_rounded,
                      active: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (_tab == 0) {
                    showDialog(
                        context: context,
                        builder: (_) => CarDialog(state: s));
                  } else {
                    showDialog(
                        context: context,
                        builder: (_) => GroupDialog(state: s));
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(
                    _tab == 0 ? "Mashina turi qo'shish" : "Mashina qo'shish",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                style: filledStyle(c.g2),
              ),
            ),
          ),
          Expanded(
            child: _tab == 0
                ? (s.cars.isEmpty
                    ? const EmptyState(
                        icon: Icons.directions_car_outlined,
                        title: "Hozircha mashina yo'q",
                        subtitle: "Pastdagi tugma orqali mashina qo'shing",
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        children: s.cars
                            .map((car) => EditableCarCard(car: car, state: s))
                            .toList(),
                      ))
                : (s.groups.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: "Xarajatlar yo'q",
                        subtitle:
                            "Mashina qo'shib, uning zapchast va narxlarini yozib boring.\nBu bo'lim statistikaga ta'sir qilmaydi — izoh kabi saqlanadi",
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        children: s.groups
                            .map((g) => ExpenseGroupCard(group: g, state: s))
                            .toList(),
                      )),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: active ? c.gradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? Colors.white : c.gray, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white : c.gray,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ---------- Mashina turi (tahrirlanadigan) ----------
class EditableCarCard extends StatefulWidget {
  final CarType car;
  final AppState state;
  const EditableCarCard({super.key, required this.car, required this.state});
  @override
  State<EditableCarCard> createState() => _EditableCarCardState();
}

class _EditableCarCardState extends State<EditableCarCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final car = widget.car;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(c),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: c.brand.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                        child: Text(car.icon,
                            style: const TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(car.name,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.text)),
                        Text('${car.works.length} ta ish turi',
                            style: TextStyle(fontSize: 13, color: c.gray)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    color: c.brand,
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => CarDialog(state: widget.state, car: car),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: c.red,
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: "O'chirish",
                        message:
                            "«${car.name}» mashina turi o'chirilsinmi? Undagi barcha ish turlari ham o'chiriladi.",
                        yes: "O'chirish",
                        no: 'Bekor qilish',
                        color: c.red,
                      );
                      if (ok) widget.state.deleteCar(car.id);
                    },
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, color: c.gray),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (car.works.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.field,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                          "Ish turi qo'shilmagan. «Ish qo'shish» tugmasidan foydalaning.",
                          style: TextStyle(color: c.gray, fontSize: 13)),
                    )
                  else
                    ...car.works.map((w) => _WorkRow(
                          work: w,
                          onEdit: () => openWorkDialog(
                              context, widget.state, car, w),
                          onDelete: () {
                            car.works.removeWhere((e) => e.id == w.id);
                            widget.state.saveCars();
                          },
                        )),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          openWorkDialog(context, widget.state, car),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text("Ish qo'shish"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.brand,
                        side: BorderSide(color: c.brand.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  final WorkItem work;
  final VoidCallback onEdit, onDelete;
  const _WorkRow(
      {required this.work, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(work.name,
                style: TextStyle(
                    fontSize: 14,
                    color: c.text,
                    fontWeight: FontWeight.w500)),
          ),
          Text(formatPrice(work.price),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: c.brand, fontSize: 13)),
          const SizedBox(width: 4),
          Text(som, style: TextStyle(color: c.gray, fontSize: 11)),
          const SizedBox(width: 8),
          InkWell(
            onTap: onEdit,
            child: Icon(Icons.edit_rounded, size: 18, color: c.brand),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onDelete,
            child: Icon(Icons.delete_outline_rounded, size: 18, color: c.red),
          ),
        ],
      ),
    );
  }
}

// ---------- Xarajat guruhi (mashina) kartasi ----------
class ExpenseGroupCard extends StatelessWidget {
  final ExpenseGroup group;
  final AppState state;
  const ExpenseGroupCard({super.key, required this.group, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final g = group;
    final col = g.paid ? c.green : c.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(c, border: col.withOpacity(0.35)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseGroupScreen(state: state, group: g),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: col.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.directions_car_filled_rounded,
                      color: col, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.carName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: c.text)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (g.plate.isNotEmpty) g.plate,
                          '${g.items.length} ta qism',
                          fmtDate(g.date),
                        ].join(' • '),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.gray),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatPrice(g.total),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: col,
                            fontSize: 16)),
                    Text(g.paid ? "to'langan" : "to'lanmagan",
                        style: TextStyle(
                            fontSize: 11,
                            color: col,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: c.gray),
                  onSelected: (v) async {
                    if (v == 'edit') {
                      showDialog(
                        context: context,
                        builder: (_) => GroupDialog(state: state, group: g),
                      );
                    } else {
                      final ok = await confirmDialog(
                        context,
                        title: "O'chirish",
                        message:
                            "«${g.carName}» va undagi barcha qismlar o'chirilsinmi?",
                        yes: "O'chirish",
                        no: 'Bekor qilish',
                        color: c.red,
                      );
                      if (ok) state.deleteGroup(g.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                    PopupMenuItem(value: 'delete', child: Text("O'chirish")),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Xarajat guruhi ichki ekrani ----------
class ExpenseGroupScreen extends StatelessWidget {
  final AppState state;
  final ExpenseGroup group;
  const ExpenseGroupScreen({super.key, required this.state, required this.group});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final c = context.c;
        final g = group;
        final col = g.paid ? c.green : c.red;
        return Scaffold(
          backgroundColor: c.bg,
          appBar: HeaderBar(title: g.carName, back: true),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(c, r: 16),
                child: Row(
                  children: [
                    Icon(Icons.directions_car_filled_rounded,
                        color: c.brand, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.carName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: c.text)),
                          Text(
                            g.plate.isEmpty
                                ? 'Raqam kiritilmagan'
                                : 'Raqam: ${g.plate}',
                            style: TextStyle(color: c.gray, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: col.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(g.paid ? "To'langan" : "To'lanmagan",
                          style: TextStyle(
                              color: col,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Zapchastlar',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
              const SizedBox(height: 10),
              if (g.items.isEmpty)
                const NotFoundBox(text: "Hali zapchast qo'shilmagan")
              else
                ...g.items.asMap().entries.map((e) {
                  final it = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: cardDeco(c, r: 14),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => openPartDialog(context, state, g, it),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          child: Row(
                            children: [
                              Text('${e.key + 1}.',
                                  style: TextStyle(
                                      color: c.gray,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(it.name,
                                    style: TextStyle(
                                        color: c.text,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500)),
                              ),
                              Text('${formatPrice(it.price)} $som',
                                  style: TextStyle(
                                      color: col,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 20, color: c.red),
                                onPressed: () async {
                                  final ok = await confirmDialog(
                                    context,
                                    title: "O'chirish",
                                    message:
                                        "«${it.name}» ro'yxatdan o'chirilsinmi?",
                                    yes: "O'chirish",
                                    no: 'Bekor qilish',
                                    color: c.red,
                                  );
                                  if (ok) {
                                    g.items.removeWhere((x) => x.id == it.id);
                                    state.saveGroups();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => openPartDialog(context, state, g),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Zapchast qo'shish"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.brand,
                  side: BorderSide(color: c.brand.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border.all(color: c.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(c.dark ? 0.4 : 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Jami narx:',
                          style: TextStyle(color: c.gray, fontSize: 14)),
                      Text('${formatPrice(g.total)} $som',
                          style: TextStyle(
                              color: col,
                              fontSize: 21,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!g.paid)
                    FilledButton.icon(
                      onPressed: () async {
                        if (g.items.isEmpty) {
                          toast(context, "Avval zapchast qo'shing");
                          return;
                        }
                        final ok = await confirmDialog(
                          context,
                          title: "To'landimi?",
                          message:
                              "Ishonchingiz komilmi? ${formatPrice(g.total)} $som \"to'landi\" deb belgilanadi.",
                          yes: "Ha, to'landi",
                          no: 'Bekor qilish',
                          color: c.green,
                        );
                        if (ok) {
                          g.paid = true;
                          state.saveGroups();
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text("To'landi",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      style: filledStyle(c.green),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await confirmDialog(
                          context,
                          title: "Qaytarilsinmi?",
                          message:
                              "Ishonchingiz komilmi? Holat qaytadan \"to'lanmagan\" bo'ladi.",
                          yes: 'Ha, qaytarish',
                          no: 'Bekor qilish',
                          color: c.red,
                        );
                        if (ok) {
                          g.paid = false;
                          state.saveGroups();
                        }
                      },
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text("To'lanmagan deb qaytarish"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.red,
                        side: BorderSide(color: c.red.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
//  DIALOGLAR
// =========================================================
void openWorkDialog(BuildContext context, AppState state, CarType car,
    [WorkItem? work]) {
  showDialog(
    context: context,
    builder: (ctx) => NamePriceDialog(
      title: work == null ? "Yangi ish qo'shish" : 'Ishni tahrirlash',
      nameLabel: 'Ish nomi',
      nameHint: 'Masalan: Moy almashtirish',
      initialName: work?.name ?? '',
      initialPrice: work?.price,
      color: ctx.c.brand,
      onSave: (n, p) {
        if (work != null) {
          work.name = n;
          work.price = p;
        } else {
          car.works.add(WorkItem(id: uid(), name: n, price: p));
        }
        state.saveCars();
      },
    ),
  );
}

void openPartDialog(BuildContext context, AppState state, ExpenseGroup g,
    [WorkItem? item]) {
  showDialog(
    context: context,
    builder: (ctx) => NamePriceDialog(
      title: item == null ? "Zapchast qo'shish" : 'Zapchastni tahrirlash',
      nameLabel: 'Zapchast nomi',
      nameHint: 'Masalan: Moy filtri',
      initialName: item?.name ?? '',
      initialPrice: item?.price,
      color: ctx.c.brand,
      onSave: (n, p) {
        if (item != null) {
          item.name = n;
          item.price = p;
        } else {
          g.items.add(WorkItem(id: uid(), name: n, price: p));
        }
        state.saveGroups();
      },
    ),
  );
}

class NamePriceDialog extends StatefulWidget {
  final String title, nameLabel, nameHint, initialName;
  final double? initialPrice;
  final Color color;
  final void Function(String name, double price) onSave;
  const NamePriceDialog({
    super.key,
    required this.title,
    required this.nameLabel,
    required this.nameHint,
    required this.initialName,
    required this.initialPrice,
    required this.color,
    required this.onSave,
  });
  @override
  State<NamePriceDialog> createState() => _NamePriceDialogState();
}

class _NamePriceDialogState extends State<NamePriceDialog> {
  late final TextEditingController _name, _price;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _price = TextEditingController(
        text: widget.initialPrice == null
            ? ''
            : formatPrice(widget.initialPrice!));
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title,
          style: TextStyle(
              color: widget.color, fontWeight: FontWeight.bold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: widget.nameLabel,
              controller: _name,
              hint: widget.nameHint,
              autofocus: true,
              caps: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: "Narxi ($som)",
              controller: _price,
              hint: '0',
              suffix: som,
              keyboardType: TextInputType.number,
              formatters: [MoneyFormatter()],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: () {
            final n = _name.text.trim();
            final p = parseMoney(_price.text);
            if (n.isEmpty) {
              toast(context, 'Nomini kiriting');
              return;
            }
            if (p <= 0) {
              toast(context, 'Narxini kiriting');
              return;
            }
            widget.onSave(n, p);
            Navigator.pop(context);
          },
          style: filledStyle(widget.color, vertical: 12),
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}

class CarDialog extends StatefulWidget {
  final AppState state;
  final CarType? car;
  const CarDialog({super.key, required this.state, this.car});
  @override
  State<CarDialog> createState() => _CarDialogState();
}

class _CarDialogState extends State<CarDialog> {
  late TextEditingController _nameCtrl;
  String _icon = '🚗';

  static const _icons = [
    '🚗', '🚙', '🚕', '🚚', '🚐', '🚛',
    '🏍️', '🛵', '🚜', '🚌', '🚎', '🚓'
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.car?.name ?? '');
    _icon = widget.car?.icon ?? '🚗';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isEdit = widget.car != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isEdit ? 'Mashina tahrirlash' : 'Yangi mashina turi',
          style: TextStyle(
              color: c.brand, fontWeight: FontWeight.bold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledField(
              label: 'Nomi',
              controller: _nameCtrl,
              hint: 'Masalan: Nexia',
              autofocus: true,
              caps: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text('Belgi', style: TextStyle(fontSize: 13, color: c.gray)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((e) {
                final sel = e == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: sel ? c.g2 : c.field,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? c.g2 : c.divider,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: _save,
          style: filledStyle(c.g2, vertical: 12),
          child: Text(isEdit ? 'Saqlash' : "Qo'shish"),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      toast(context, 'Nomini kiriting');
      return;
    }
    if (widget.car != null) {
      widget.car!.name = name;
      widget.car!.icon = _icon;
      widget.state.saveCars();
    } else {
      widget.state.addCar(CarType(id: uid(), name: name, icon: _icon));
    }
    Navigator.pop(context);
  }
}

/// Xarajatlar bo'limi: mashina (nomi + ixtiyoriy raqam) qo'shish / tahrirlash
class GroupDialog extends StatefulWidget {
  final AppState state;
  final ExpenseGroup? group;
  const GroupDialog({super.key, required this.state, this.group});
  @override
  State<GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<GroupDialog> {
  late TextEditingController _name, _plate;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group?.carName ?? '');
    _plate = TextEditingController(text: widget.group?.plate ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isEdit = widget.group != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isEdit ? 'Mashinani tahrirlash' : 'Yangi mashina',
          style: TextStyle(
              color: c.brand, fontWeight: FontWeight.bold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledField(
              label: 'Mashina nomi',
              controller: _name,
              hint: 'Masalan: Nexia 3',
              icon: Icons.directions_car_rounded,
              autofocus: true,
              caps: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Mashina raqami (ixtiyoriy)',
              controller: _plate,
              hint: '01A123BC',
              icon: Icons.pin_rounded,
              caps: TextCapitalization.characters,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: _save,
          style: filledStyle(c.g2, vertical: 12),
          child: Text(isEdit ? 'Saqlash' : "Qo'shish"),
        ),
      ],
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Mashina nomini kiriting');
      return;
    }
    final plate = _plate.text.trim().toUpperCase();
    if (widget.group != null) {
      widget.group!.carName = name;
      widget.group!.plate = plate;
      widget.state.saveGroups();
      Navigator.pop(context);
    } else {
      final g = ExpenseGroup(
        id: uid(),
        carName: name,
        plate: plate,
        date: DateTime.now(),
      );
      widget.state.addGroup(g);
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExpenseGroupScreen(state: widget.state, group: g),
        ),
      );
    }
  }
}

class UstaDialog extends StatefulWidget {
  final AppState state;
  const UstaDialog({super.key, required this.state});
  @override
  State<UstaDialog> createState() => _UstaDialogState();
}

class _UstaDialogState extends State<UstaDialog> {
  late TextEditingController _nameCtrl, _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.state.usta.name);
    _phoneCtrl = TextEditingController(text: widget.state.usta.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.person_rounded, color: c.brand),
          const SizedBox(width: 8),
          Text("Usta ma'lumotlari",
              style: TextStyle(
                  color: c.brand, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledField(
              label: 'Ism Familiya',
              controller: _nameCtrl,
              hint: 'Masalan: Akmal Usta',
              icon: Icons.person_outline_rounded,
              autofocus: true,
              caps: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Telefon',
              controller: _phoneCtrl,
              hint: '+998 90 123 45 67',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            Text("Bu ma'lumotlar chekka avtomatik qo'shiladi.",
                style: TextStyle(color: c.light, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: () {
            widget.state.saveUsta(UstaInfo(
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
            ));
            Navigator.pop(context);
          },
          style: filledStyle(c.g2, vertical: 12),
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}

// =========================================================
//  STATISTIKA SCREEN — Daromad / To'langan / Qarz
//  (Xarajatlar bo'limi bu yerga qo'shilmaydi)
// =========================================================
class StatistikaScreen extends StatefulWidget {
  final AppState state;
  const StatistikaScreen({super.key, required this.state});
  @override
  State<StatistikaScreen> createState() => _StatistikaScreenState();
}

class _StatistikaScreenState extends State<StatistikaScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all | debt

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = context.c;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));
    final yearAgo = now.subtract(const Duration(days: 365));

    double wI = 0, mI = 0, yI = 0, aI = 0;
    double wR = 0, mR = 0, yR = 0, aR = 0;
    double debt = 0;
    int debtCount = 0;

    for (final r in s.records) {
      aI += r.total;
      if (r.date.isAfter(weekAgo)) wI += r.total;
      if (r.date.isAfter(monthAgo)) mI += r.total;
      if (r.date.isAfter(yearAgo)) yI += r.total;
      if (r.isDebt) {
        debt += r.debt;
        debtCount++;
      }
      for (final p in r.payments) {
        aR += p.amount;
        if (p.date.isAfter(weekAgo)) wR += p.amount;
        if (p.date.isAfter(monthAgo)) mR += p.amount;
        if (p.date.isAfter(yearAgo)) yR += p.amount;
      }
    }

    List<ServiceRecord> filtered = s.records;
    if (_filter == 'debt') {
      filtered = filtered.where((r) => r.isDebt).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.carTypeName.toLowerCase().contains(q) ||
              r.customerName.toLowerCase().contains(q) ||
              r.customerPhone.toLowerCase().contains(q) ||
              r.carPlate.toLowerCase().contains(q) ||
              r.works.any((w) => w.name.toLowerCase().contains(q)))
          .toList();
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: HeaderBar(title: 'Statistika', actions: mainActions(context, s)),
      body: s.records.isEmpty
          ? const EmptyState(
              icon: Icons.bar_chart_rounded,
              title: "Hozircha ma'lumot yo'q",
              subtitle:
                  "Asosiy menyudan ish saqlang, statistika avtomatik to'planadi",
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
              children: [
                // Asosiy kartochka
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: c.gradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: c.g1.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jami daromad',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('${formatPrice(aI)} $som',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStat(
                              label: "To'langan",
                              value: formatPrice(aR),
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF34D399),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniStat(
                              label: 'Qarz',
                              value: formatPrice(debt),
                              icon: Icons.schedule_rounded,
                              color: const Color(0xFFFCA5A5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Qarzdorlar kartochkasi
                if (debtCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: c.red.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.red.withOpacity(0.35)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DebtorsScreen(state: s),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: c.red,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(Icons.warning_amber_rounded,
                                    color: Colors.white, size: 25),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Qarzdorlar',
                                        style: TextStyle(
                                            color: c.red,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15)),
                                    Text("$debtCount ta • to'lash uchun bosing",
                                        style: TextStyle(
                                            color: c.gray, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(formatPrice(debt),
                                      style: TextStyle(
                                          color: c.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  Text(som,
                                      style:
                                          TextStyle(color: c.red, fontSize: 11)),
                                ],
                              ),
                              Icon(Icons.chevron_right_rounded, color: c.red),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _PeriodCard(
                        title: 'Hafta',
                        icon: Icons.calendar_view_week_rounded,
                        income: wI,
                        received: wR,
                        color: const Color(0xFF3A7BD5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PeriodCard(
                        title: 'Oy',
                        icon: Icons.calendar_month_rounded,
                        income: mI,
                        received: mR,
                        color: c.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PeriodCard(
                  title: 'Yil',
                  icon: Icons.date_range_rounded,
                  income: yI,
                  received: yR,
                  color: c.amber,
                  wide: true,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Barcha ishlar tarixi',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                    Text('${s.records.length} ta',
                        style: TextStyle(color: c.gray, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatChip(
                        label: 'Hammasi',
                        active: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all')),
                    const SizedBox(width: 8),
                    _StatChip(
                        label: 'Qarzdorlar',
                        active: _filter == 'debt',
                        onTap: () => setState(() => _filter = 'debt'),
                        count: debtCount,
                        danger: true),
                  ],
                ),
                const SizedBox(height: 12),
                SearchField(
                  controller: _searchCtrl,
                  hint: 'Qidirish: mashina, mijoz, raqam, ish...',
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const NotFoundBox()
                else
                  ...filtered
                      .map((r) => RecordTile(record: r, state: s, showWorks: true)),
              ],
            ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;
  final bool danger;
  const _StatChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final activeColor = danger ? c.red : c.g2;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? activeColor : c.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: active
                        ? Colors.white
                        : (danger ? c.red : c.gray),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5)),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withOpacity(0.3)
                      : c.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count',
                    style: TextStyle(
                        color: active ? Colors.white : c.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double income, received;
  final Color color;
  final bool wide;
  const _PeriodCard({
    required this.title,
    required this.icon,
    required this.income,
    required this.received,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      color: c.gray,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Text('${formatPrice(income)} $som',
              style: TextStyle(
                fontSize: wide ? 19 : 16,
                fontWeight: FontWeight.bold,
                color: c.text,
              )),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 13, color: c.green),
              const SizedBox(width: 4),
              Flexible(
                child: Text("To'langan: ${formatPrice(received)}",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: c.green,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================
//  QARZDORLAR EKRANI — qarzni qisman / to'liq to'lash
// =========================================================
class DebtorsScreen extends StatelessWidget {
  final AppState state;
  const DebtorsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final c = context.c;
        final list = state.records.where((r) => r.isDebt).toList()
          ..sort((a, b) => b.debt.compareTo(a.debt));
        final total = list.fold(0.0, (sum, r) => sum + r.debt);
        return Scaffold(
          backgroundColor: c.bg,
          appBar: HeaderBar(title: 'Qarzdorlar', back: true),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.celebration_rounded,
                  title: "Qarzdorlar yo'q",
                  subtitle: "Barcha qarzlar to'langan 🎉",
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: c.red.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Jami qarz',
                                  style: TextStyle(
                                      color: c.gray, fontSize: 13)),
                              Text('${list.length} ta mijoz',
                                  style: TextStyle(
                                      color: c.gray, fontSize: 12)),
                            ],
                          ),
                          Text('${formatPrice(total)} $som',
                              style: TextStyle(
                                  color: c.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text("To'lov qabul qilish uchun mijozni bosing",
                        style: TextStyle(color: c.gray, fontSize: 13)),
                    const SizedBox(height: 10),
                    ...list.map((r) => _debtTile(context, c, r)),
                  ],
                ),
        );
      },
    );
  }

  Widget _debtTile(BuildContext context, AppPalette c, ServiceRecord r) {
    final who = r.customerName.isNotEmpty ? r.customerName : r.carTypeName;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDeco(c, r: 16, border: c.red.withOpacity(0.3)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showDialog(
            context: context,
            builder: (_) => PayDebtDialog(state: state, record: r),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(r.carIcon, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(who,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (r.customerPhone.isNotEmpty) r.customerPhone,
                              r.carTypeName,
                              if (r.carPlate.isNotEmpty) r.carPlate,
                              fmtDate(r.date),
                            ].join(' • '),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.gray),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatPrice(r.debt),
                            style: TextStyle(
                                color: c.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                        Text("$som qarz",
                            style: TextStyle(color: c.red, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: r.total <= 0 ? 0 : (r.paid / r.total).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: c.red.withOpacity(0.18),
                    color: c.green,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("To'langan: ${formatPrice(r.paid)}",
                        style: TextStyle(
                            color: c.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text('Jami: ${formatPrice(r.total)}',
                        style: TextStyle(color: c.gray, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) =>
                              PayDebtDialog(state: state, record: r),
                        ),
                        icon: const Icon(Icons.add_card_rounded, size: 18),
                        label: const Text("To'lov qabul qilish"),
                        style: filledStyle(c.green, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReceiptScreen(state: state, record: r),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.brand,
                        side: BorderSide(color: c.brand.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
