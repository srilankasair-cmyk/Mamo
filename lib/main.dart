import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
// intl imported in screens where needed
import 'store.dart';
import 'screens/home.dart';
// removed MyParty and Registrations screens from navigation
import 'screens/details.dart';
import 'screens/edit_party.dart';
import 'screens/register.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await PartyStore.create();
  runApp(MyApp(store: store));
}

class MyApp extends StatelessWidget {
  final PartyStore store;
  const MyApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PartyStore>.value(
      value: store,
      child: MaterialApp(
        title: 'Parties',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF39FF14)),
          primaryColor: const Color(0xFF39FF14),
          scaffoldBackgroundColor: const Color(0xFFF4E7D9), // lighter light-brown background
          disabledColor: const Color(0xFFEEE0CF), // softer disabled tone
          // Use a vintage serif font (Lora) via Google Fonts
          textTheme: GoogleFonts.loraTextTheme(ThemeData.light().textTheme).copyWith(
            bodySmall: GoogleFonts.lora(fontSize: 14, height: 1.35),
            bodyMedium: GoogleFonts.lora(fontSize: 16, height: 1.4),
            bodyLarge: GoogleFonts.lora(fontSize: 18, height: 1.4),
            titleSmall: GoogleFonts.lora(fontSize: 16, fontWeight: FontWeight.w600),
            titleMedium: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w700),
            titleLarge: GoogleFonts.lora(fontSize: 22, fontWeight: FontWeight.w700),
            headlineSmall: GoogleFonts.lora(fontSize: 26, fontWeight: FontWeight.w700),
            headlineMedium: GoogleFonts.lora(fontSize: 30, fontWeight: FontWeight.w800),
            headlineLarge: GoogleFonts.lora(fontSize: 36, fontWeight: FontWeight.w800),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black,
            // hide title text globally for immersive header; keep icons visible
            titleTextStyle: TextStyle(color: Colors.transparent, fontSize: 20, fontWeight: FontWeight.bold),
            toolbarTextStyle: TextStyle(color: Colors.transparent),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w600),
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFFF8F1E7),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xFF1B5E20), foregroundColor: Colors.white),
        ),
        onGenerateRoute: (settings) {
          // support path like /party/ID
          if (settings.name != null && settings.name!.startsWith('/party/')) {
            final id = settings.name!.split('/').last.split('?').first;
            return MaterialPageRoute(builder: (_) => PartyDetailsScreen(partyId: id));
          }
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const RootScaffold(initialIndex: 0));
            case '/my':
              return MaterialPageRoute(builder: (_) => const RootScaffold(initialIndex: 1));
            case '/joined':
              return MaterialPageRoute(builder: (_) => const RootScaffold(initialIndex: 2));
            case EditPartyScreen.routeName:
              final args = settings.arguments as EditArgs?;
              return MaterialPageRoute(builder: (_) => EditPartyScreen(args: args));
            case RegisterScreen.routeName:
              final args = settings.arguments as RegisterArgs;
              return MaterialPageRoute(builder: (_) => RegisterScreen(args: args));
            default:
              return MaterialPageRoute(builder: (_) => const RootScaffold(initialIndex: 0));
          }
        },
      ),
    );
  }
}

class RootScaffold extends StatefulWidget {
  final int initialIndex;
  const RootScaffold({super.key, this.initialIndex = 0});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  late int _index;
  final pages = [HomeScreen()];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const SizedBox.shrink(),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final maxWidth = 900.0;
        final content = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: pages[_index],
        );
        if (constraints.maxWidth > 900) {
          return Center(child: Padding(padding: const EdgeInsets.all(16), child: content));
        }
        return Padding(padding: const EdgeInsets.all(8), child: content);
      }),
      bottomNavigationBar: pages.length > 1
          ? BottomNavigationBar(
              currentIndex: _index,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              ],
              onTap: (i) => setState(() => _index = i),
            )
          : null,
    );
  }
}
