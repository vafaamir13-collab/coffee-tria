// ☕ کافه هوشمند - پروژه پودمان ۱ (نسخه فلاتر)
// فقط همین فایل را در lib/main.dart پروژه‌ات کپی کن. هیچ پکیج اضافه‌ای لازم نیست.
// رمز مدیر: 1234  |  کدهای تخفیف: CAFE10 , NEW15 , VIP20
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const CafeApp());

// ======================= ابزارها =======================
String fa(Object n) {
  const e = '0123456789', p = '۰۱۲۳۴۵۶۷۸۹';
  var s = n.toString();
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(e[i], p[i]);
  }
  return s;
}

String toEn(String s) {
  const e = '0123456789', p = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(p[i], e[i]);
  }
  return s;
}

String money(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  return fa(b.toString());
}

String two(int n) => n.toString().padLeft(2, '0');

void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
}

const catNames = {'hot': 'گرم', 'cold': 'سرد', 'cake': 'کیک'};
Color catColor(String c) =>
    c == 'hot' ? const Color(0xFF8D5524) : c == 'cold' ? const Color(0xFF1E88E5) : const Color(0xFFD81B60);

// ======================= مدل‌ها =======================
class Item {
  final String key, name, cat;
  final IconData icon;
  int price, stock;
  Item(this.key, this.name, this.cat, this.price, this.stock, this.icon);
}

class Line {
  final Item item;
  int qty;
  Line(this.item, this.qty);
}

class InvRow {
  final String name;
  final int qty, sum;
  InvRow(this.name, this.qty, this.sum);
}

class Invoice {
  final String customer, time;
  final int table, subtotal, percent, loyalty, total;
  final List<InvRow> rows;
  Invoice(this.customer, this.table, this.time, this.rows, this.subtotal, this.percent, this.loyalty, this.total);
}

class Cust {
  final String name;
  final int table;
  Cust(this.name, this.table);
}

// ======================= منطق برنامه =======================
class Store extends ChangeNotifier {
  final rnd = Random();
  final adminPass = '1234';
  final items = <Item>[
    Item('espresso', 'اسپرسو', 'hot', 60000, 20, Icons.coffee),
    Item('latte', 'لاته', 'hot', 95000, 15, Icons.local_cafe),
    Item('cappuccino', 'کاپوچینو', 'hot', 90000, 12, Icons.coffee_maker),
    Item('mocha', 'موکا', 'hot', 105000, 8, Icons.emoji_food_beverage),
    Item('tea_masala', 'چای ماسالا', 'hot', 70000, 10, Icons.free_breakfast),
    Item('latte_iced', 'آیس لاته', 'cold', 100000, 10, Icons.local_drink),
    Item('lemonade', 'لیموناد', 'cold', 75000, 6, Icons.local_bar),
    Item('cheesecake', 'چیزکیک', 'cake', 120000, 5, Icons.cake),
    Item('brownie', 'براونی', 'cake', 85000, 2, Icons.bakery_dining),
  ];
  final codes = <String, int>{'CAFE10': 10, 'NEW15': 15, 'VIP20': 20};
  final cart = <Line>[];
  final sales = <String, int>{};
  final visits = <String, int>{};
  final invoices = <Invoice>[];
  final customers = <Cust>[];
  int revenue = 0;
  bool admin = false;
  int? fakeHour; // برای تست ساعت شاد
  String customer = '';
  int table = 1;
  String? code;
  Invoice? lastInvoice;
  String? lastBonus;
  late String lucky = items[rnd.nextInt(items.length)].key;

  int get hour => fakeHour ?? DateTime.now().hour;
  bool get happy => hour >= 14 && hour < 16;
  void toggleFake() {
    fakeHour = fakeHour == null ? 15 : null;
    notifyListeners();
  }

  Item byKey(String k) => items.firstWhere((i) => i.key == k);

  // قیمت واحد با ساعت شاد (۲۰٪ سرد) و پیشنهاد شانسی (۱۰٪)
  int unitPrice(Item i) {
    double p = i.price.toDouble();
    if (happy && i.cat == 'cold') p *= 0.8;
    if (i.key == lucky) p *= 0.9;
    return p.round();
  }

  int inCart(Item i) => cart.where((l) => l.item == i).fold(0, (a, l) => a + l.qty);
  int available(Item i) => i.stock - inCart(i);

  String? addToCart(Item i, int q) {
    if (q <= 0) return 'تعداد باید عدد صحیح و بزرگ‌تر از صفر باشد';
    if (q > available(i)) return 'فقط ${fa(available(i))} عدد مانده';
    final ex = cart.where((l) => l.item == i).toList();
    if (ex.isNotEmpty) {
      ex.first.qty += q;
    } else {
      cart.add(Line(i, q));
    }
    notifyListeners();
    return null;
  }

  void removeLine(int i) {
    cart.removeAt(i);
    notifyListeners();
  }

  int get subtotal => cart.fold(0, (a, l) => a + unitPrice(l.item) * l.qty);
  int get tier => subtotal > 200000 ? 10 : subtotal > 100000 ? 5 : 0;
  int get codePct => codes[code] ?? 0;
  int get percent => max(tier, codePct); // فقط تخفیف بزرگ‌تر
  int get discountAmt => (subtotal * percent / 100).round();
  bool get loyaltyDue =>
      cart.isNotEmpty && customer.trim().isNotEmpty && ((visits[customer.trim()] ?? 0) + 1) % 10 == 0;
  int get loyaltyAmt => loyaltyDue ? cart.map((l) => unitPrice(l.item)).reduce(min) : 0;
  int get total => max(0, subtotal - discountAmt - loyaltyAmt);

  String? applyCode(String c) {
    c = c.trim().toUpperCase();
    if (c.isEmpty) {
      code = null;
      notifyListeners();
      return null;
    }
    if (!codes.containsKey(c)) return 'کد تخفیف معتبر نیست';
    code = c;
    notifyListeners();
    return null;
  }

  String? checkout() {
    final name = customer.trim();
    if (cart.isEmpty) return 'سفارش خالی است';
    if (name.isEmpty) return 'نام مشتری را وارد کنید';
    final n = DateTime.now();
    final rows = [for (final l in cart) InvRow(l.item.name, l.qty, unitPrice(l.item) * l.qty)];
    final inv = Invoice(name, table, '${n.year}/${two(n.month)}/${two(n.day)}  ${two(n.hour)}:${two(n.minute)}',
        rows, subtotal, percent, loyaltyAmt, total);
    for (final l in cart) {
      l.item.stock -= l.qty;
      sales[l.item.key] = (sales[l.item.key] ?? 0) + l.qty;
    }
    visits[name] = (visits[name] ?? 0) + 1;
    customers.add(Cust(name, table));
    revenue += inv.total;
    invoices.insert(0, inv);
    lastBonus = null;
    if (inv.total > 300000) {
      // کد تخفیف ۶ حرفی تصادفی برای خرید بالای ۳۰۰ هزار
      lastBonus = String.fromCharCodes(List.generate(6, (_) => 65 + rnd.nextInt(26)));
      codes[lastBonus!] = 15;
    }
    cart.clear();
    code = null;
    customer = '';
    lastInvoice = inv;
    notifyListeners();
    return null;
  }

  void setAdmin(bool v) {
    admin = v;
    notifyListeners();
  }

  void restock(Item i, int q) {
    i.stock += q;
    notifyListeners();
  }

  void setPrice(Item i, int p) {
    i.price = p;
    notifyListeners();
  }

  void addItem(String name, int price, int stock, String cat) {
    final icon = cat == 'hot' ? Icons.coffee : cat == 'cold' ? Icons.local_drink : Icons.cake;
    items.add(Item('item_${items.length}_${rnd.nextInt(999)}', name, cat, price, stock, icon));
    notifyListeners();
  }
}

final store = Store();

// ======================= برنامه =======================
class CafeApp extends StatelessWidget {
  const CafeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'کافه هوشمند',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6F4E37)),
        scaffoldBackgroundColor: const Color(0xFFFAF5EF),
      ),
      builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        const pages = [MenuPage(), CartPage(), StockPage(), ReportPage()];
        final cnt = store.cart.fold(0, (a, l) => a + l.qty);
        return Scaffold(
          appBar: AppBar(
            title: const Text('☕ کافه هوشمند', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'تست ساعت شاد (۱۵:۰۰)',
                icon: Icon(store.fakeHour != null ? Icons.bolt : Icons.bolt_outlined,
                    color: store.happy ? Colors.orange : null),
                onPressed: store.toggleFake,
              ),
            ],
          ),
          body: pages[tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'منو'),
              NavigationDestination(
                icon: Badge(label: Text(fa(cnt)), isLabelVisible: cnt > 0, child: const Icon(Icons.shopping_cart)),
                label: 'سفارش',
              ),
              const NavigationDestination(icon: Icon(Icons.inventory_2), label: 'انبار'),
              const NavigationDestination(icon: Icon(Icons.bar_chart), label: 'گزارش'),
            ],
          ),
        );
      },
    );
  }
}

// ======================= دیالوگ‌ها =======================
Future<void> askQty(BuildContext context, Item it) async {
  final c = TextEditingController(text: '1');
  String? err;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(it.name),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('موجودی: ${fa(store.available(it))} عدد'),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'تعداد', errorText: err, border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(
            onPressed: () {
              final q = int.tryParse(toEn(c.text.trim()));
              final e = q == null ? 'تعداد باید عدد صحیح و بزرگ‌تر از صفر باشد' : store.addToCart(it, q);
              if (e != null) {
                set(() => err = e);
              } else {
                Navigator.pop(ctx);
                toast(context, '${it.name} × ${fa(q!)} به سفارش اضافه شد ✅');
              }
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> prompt(BuildContext context, String title, String label, {String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, toEn(c.text.trim())), child: const Text('تأیید')),
      ],
    ),
  );
}

Future<void> adminLogin(BuildContext context) async {
  final c = TextEditingController();
  int tries = 0;
  String? err;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('ورود مدیر 🔐'),
        content: TextField(
          controller: c,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'رمز مدیر', errorText: err, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(
            onPressed: () {
              if (toEn(c.text.trim()) == store.adminPass) {
                store.setAdmin(true);
                Navigator.pop(ctx);
                toast(context, 'خوش آمدی مدیر ✅');
              } else {
                tries++;
                if (tries >= 3) {
                  Navigator.pop(ctx);
                  toast(context, '۳ بار رمز اشتباه! بازگشت به منو.');
                } else {
                  c.clear();
                  set(() => err = 'رمز اشتباه است (${fa(3 - tries)} تلاش مانده)');
                }
              }
            },
            child: const Text('ورود'),
          ),
        ],
      ),
    ),
  );
}

Future<void> addItemDialog(BuildContext context) async {
  final n = TextEditingController(), p = TextEditingController(), s = TextEditingController();
  String cat = 'hot';
  String? err;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('آیتم جدید'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: n, decoration: const InputDecoration(labelText: 'نام', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: p,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'قیمت (تومان)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: s,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'موجودی', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: cat,
              items: [for (final e in catNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => set(() => cat = v!),
              decoration: const InputDecoration(labelText: 'دسته', border: OutlineInputBorder()),
            ),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(
            onPressed: () {
              final pr = int.tryParse(toEn(p.text.trim())), st = int.tryParse(toEn(s.text.trim()));
              if (n.text.trim().isEmpty || pr == null || pr <= 0 || st == null || st < 0) {
                set(() => err = 'همه فیلدها را درست پر کن');
                return;
              }
              store.addItem(n.text.trim(), pr, st, cat);
              Navigator.pop(ctx);
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    ),
  );
}

Widget kv(String k, String v, {bool bold = false, Color? color}) {
  final st = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 17 : 14, color: color);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: st), Text(v, style: st)]),
  );
}

void showInvoice(BuildContext context, Invoice v, {String? bonus}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Center(child: Text('☕ کافه هوشمند')),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${v.customer} | میز ${fa(v.table)}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(fa(v.time), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const Divider(),
            for (final r in v.rows) kv('${r.name} × ${fa(r.qty)}', money(r.sum)),
            const Divider(),
            kv('جمع کل', money(v.subtotal)),
            if (v.percent > 0)
              kv('تخفیف (${fa(v.percent)}٪)', '− ${money(v.subtotal * v.percent / 100)}', color: Colors.green),
            if (v.loyalty > 0) kv('هدیه وفاداری 🎁', '− ${money(v.loyalty)}', color: Colors.green),
            const Divider(),
            kv('مبلغ نهایی', '${money(v.total)} تومان', bold: true),
            if (bonus != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
                child: Text('🎉 کد تخفیف ویژه شما: $bonus (۱۵٪)', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))],
    ),
  );
}

// ======================= صفحه منو =======================
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String f = 'all';

  Widget banner(IconData ic, String t, List<Color> cols) => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(gradient: LinearGradient(colors: cols), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(ic, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ]),
      );

  Widget card(BuildContext context, Item it) {
    final av = store.available(it);
    final out = av <= 0;
    final now = store.unitPrice(it);
    final col = catColor(it.cat);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: out ? null : () => askQty(context, it),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: col.withAlpha(35), borderRadius: BorderRadius.circular(14)),
                child: Stack(children: [
                  Center(child: Icon(it.icon, size: 54, color: out ? Colors.grey : col)),
                  if (it.key == store.lucky) const Positioned(top: 6, right: 6, child: Icon(Icons.stars, color: Colors.amber)),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Text(catNames[it.cat]!, style: TextStyle(fontSize: 11, color: col, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (now != it.price)
                Text(money(it.price),
                    style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 11)),
              if (now != it.price) const SizedBox(width: 6),
              Text('${money(now)} ت', style: TextStyle(color: col, fontWeight: FontWeight.bold)),
            ]),
            Text(out ? 'ناموجود ⛔' : 'موجودی: ${fa(av)}',
                style: TextStyle(fontSize: 12, color: out ? Colors.red : (av < 3 ? Colors.orange : Colors.grey))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.items.where((i) => f == 'all' || i.cat == f).toList();
        return Column(children: [
          banner(Icons.casino, '🎲 پیشنهاد شانسی امروز: ${store.byKey(store.lucky).name} (۱۰٪ تخفیف اضافه!)',
              const [Color(0xFFFF9800), Color(0xFF8D5524)]),
          if (store.happy)
            banner(Icons.ac_unit, '🧊 ساعت شاد! نوشیدنی‌های سرد ۲۰٪ ارزان‌تر', const [Color(0xFF42A5F5), Color(0xFF1565C0)]),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              for (final e in {'all': 'همه', ...catNames}.entries)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(label: Text(e.value), selected: f == e.key, onSelected: (_) => setState(() => f = e.key)),
                ),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200, childAspectRatio: 0.78, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: list.length,
              itemBuilder: (c, i) => card(c, list[i]),
            ),
          ),
        ]);
      },
    );
  }
}

// ======================= صفحه سفارش =======================
class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final name = TextEditingController(text: store.customer);
  final code = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store;
        if (s.cart.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 8),
              Text('سفارشی ثبت نشده؛ از منو آیتم اضافه کن', style: TextStyle(color: Colors.grey)),
            ]),
          );
        }
        return ListView(padding: const EdgeInsets.all(12), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextField(
                  controller: name,
                  onChanged: (v) {
                    s.customer = v;
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                      labelText: 'نام مشتری', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: s.table,
                  items: [for (var t = 1; t <= 8; t++) DropdownMenuItem(value: t, child: Text('میز ${fa(t)}'))],
                  onChanged: (v) => s.table = v!,
                  decoration: const InputDecoration(
                      labelText: 'شماره میز', prefixIcon: Icon(Icons.table_restaurant), border: OutlineInputBorder()),
                ),
                if (s.loyaltyDue)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('🎁 دهمین بازدید این مشتری است؛ یک نوشیدنی رایگان!',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
          ),
          for (var i = 0; i < s.cart.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: catColor(s.cart[i].item.cat).withAlpha(40),
                  child: Icon(s.cart[i].item.icon, color: catColor(s.cart[i].item.cat)),
                ),
                title: Text('${fa(i + 1)}. ${s.cart[i].item.name}'),
                subtitle: Text('${fa(s.cart[i].qty)} × ${money(s.unitPrice(s.cart[i].item))}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(money(s.unitPrice(s.cart[i].item) * s.cart[i].qty), style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => s.removeLine(i)),
                ]),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'کد تخفیف',
                      prefixIcon: const Icon(Icons.local_offer),
                      border: const OutlineInputBorder(),
                      helperText: s.code != null ? 'کد ${s.code} (${fa(s.codePct)}٪) اعمال شد ✅' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final e = s.applyCode(code.text);
                    if (e != null) toast(context, e);
                  },
                  child: const Text('اعمال'),
                ),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                kv('جمع کل', money(s.subtotal)),
                kv('تخفیف پلکانی', '${fa(s.tier)}٪'),
                kv('تخفیف کد', '${fa(s.codePct)}٪'),
                kv('تخفیف اعمال‌شده (بیشترین)', '${fa(s.percent)}٪  (− ${money(s.discountAmt)})', color: Colors.green),
                if (s.loyaltyAmt > 0) kv('هدیه وفاداری', '− ${money(s.loyaltyAmt)}', color: Colors.green),
                const Divider(),
                kv('مبلغ قابل پرداخت', '${money(s.total)} تومان', bold: true),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            icon: const Icon(Icons.receipt_long),
            label: const Text('ثبت سفارش و صدور فاکتور', style: TextStyle(fontSize: 16)),
            onPressed: () {
              final e = s.checkout();
              if (e != null) {
                toast(context, e);
              } else {
                name.clear();
                code.clear();
                showInvoice(context, s.lastInvoice!, bonus: s.lastBonus);
              }
            },
          ),
        ]);
      },
    );
  }
}

// ======================= صفحه انبار =======================
class StockPage extends StatelessWidget {
  const StockPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store;
        return ListView(padding: const EdgeInsets.all(12), children: [
          Card(
            color: s.admin ? Colors.green.shade50 : null,
            child: ListTile(
              leading: Icon(s.admin ? Icons.lock_open : Icons.lock, color: s.admin ? Colors.green : Colors.grey),
              title: Text(s.admin ? 'حالت مدیر فعال است' : 'شارژ انبار فقط با رمز مدیر'),
              trailing: s.admin
                  ? TextButton(onPressed: () => s.setAdmin(false), child: const Text('خروج'))
                  : FilledButton(onPressed: () => adminLogin(context), child: const Text('ورود مدیر')),
            ),
          ),
          if (s.admin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: OutlinedButton.icon(
                  onPressed: () => addItemDialog(context), icon: const Icon(Icons.add), label: const Text('افزودن آیتم جدید به منو')),
            ),
          for (final it in s.items)
            Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: catColor(it.cat).withAlpha(40), child: Icon(it.icon, color: catColor(it.cat))),
                title: Text('${it.name}  •  ${money(it.price)} ت'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (it.stock / 20).clamp(0.0, 1.0),
                        color: it.stock < 3 ? Colors.red : Colors.green,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(fa(it.stock), style: TextStyle(fontWeight: FontWeight.bold, color: it.stock < 3 ? Colors.red : null)),
                  ]),
                ),
                trailing: s.admin
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'شارژ انبار',
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () async {
                            final v = await prompt(context, 'شارژ ${it.name}', 'تعداد افزوده‌شده');
                            final q = int.tryParse(v ?? '');
                            if (q != null && q > 0) {
                              s.restock(it, q);
                            } else if (v != null && context.mounted) {
                              toast(context, 'عدد معتبر وارد کن');
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'تغییر قیمت',
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final v = await prompt(context, 'قیمت ${it.name}', 'قیمت جدید (تومان)', initial: it.price.toString());
                            final p = int.tryParse(v ?? '');
                            if (p != null && p > 0) {
                              s.setPrice(it, p);
                            } else if (v != null && context.mounted) {
                              toast(context, 'قیمت معتبر وارد کن');
                            }
                          },
                        ),
                      ])
                    : null,
              ),
            ),
        ]);
      },
    );
  }
}

// ======================= صفحه گزارش =======================
class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  Widget stat(IconData ic, String label, String val, Color c) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(children: [
              Icon(ic, color: c, size: 28),
              const SizedBox(height: 6),
              Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
            ]),
          ),
        ),
      );

  Widget section(String title, List<Widget> children, {Color? color}) => Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store;
        final avg = s.invoices.isEmpty ? 0 : s.revenue / s.invoices.length; // جلوگیری از تقسیم بر صفر
        final sorted = s.sales.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
        final never = s.items.where((i) => (s.sales[i.key] ?? 0) == 0).toList();
        final low = [for (final i in s.items) if (i.stock < 3) i];
        final cat = {'hot': 0, 'cold': 0, 'cake': 0};
        for (final e in sorted) {
          final c = s.byKey(e.key).cat;
          cat[c] = cat[c]! + e.value;
        }
        final unique = s.customers.map((c) => c.name).toSet();
        final tables = <int, int>{};
        for (final c in s.customers) {
          tables[c.table] = (tables[c.table] ?? 0) + 1;
        }
        return ListView(padding: const EdgeInsets.all(12), children: [
          Row(children: [
            stat(Icons.payments, 'کل درآمد (تومان)', money(s.revenue), Colors.green),
            stat(Icons.receipt, 'تعداد فاکتور', fa(s.invoices.length), Colors.blue),
            stat(Icons.trending_up, 'میانگین فاکتور', money(avg), Colors.orange),
          ]),
          section('🏆 پرفروش‌ترین‌ها', [
            if (sorted.isEmpty) const Text('هنوز فروشی ثبت نشده'),
            for (var i = 0; i < sorted.length && i < 3; i++)
              kv('${fa(i + 1)}. ${s.byKey(sorted[i].key).name}', '${fa(sorted[i].value)} عدد', bold: i == 0),
          ]),
          section('📊 فروش هر دسته', [for (final e in cat.entries) kv(catNames[e.key]!, '${fa(e.value)} عدد')]),
          section('🚫 بدون فروش امروز', [Text(never.isEmpty ? 'همه آیتم‌ها فروش داشتند 🎉' : never.map((i) => i.name).join('، '))]),
          section(
            '⚠️ هشدار انبار',
            [
              Text(low.isEmpty ? 'موجودی همه چیز مناسب است ✅' : low.map((i) => '${i.name} (${fa(i.stock)})').join('، ')),
              if (low.isNotEmpty) const Text('برای فردا سفارش بده!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
            color: low.isEmpty ? null : Colors.red.shade50,
          ),
          section('👥 مشتریان امروز', [
            kv('تعداد مشتری', fa(s.customers.length)),
            kv('نام‌های بدون تکرار', fa(unique.length)),
            if (tables.isNotEmpty)
              Wrap(spacing: 6, children: [for (final e in tables.entries) Chip(label: Text('میز ${fa(e.key)}: ${fa(e.value)} نفر'))]),
            for (final e in s.visits.entries) kv(e.key, '${fa(e.value)} بازدید (${fa(10 - e.value % 10)} تا هدیه)'),
          ]),
          section('🧾 فاکتورهای امروز (برای دیدن بزن)', [
            if (s.invoices.isEmpty) const Text('فاکتوری صادر نشده'),
            for (final v in s.invoices.take(10))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long),
                title: Text('${v.customer} • میز ${fa(v.table)}'),
                subtitle: Text(fa(v.time)),
                trailing: Text(money(v.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => showInvoice(context, v),
              ),
          ]),
        ]);
      },
    );
  }
}