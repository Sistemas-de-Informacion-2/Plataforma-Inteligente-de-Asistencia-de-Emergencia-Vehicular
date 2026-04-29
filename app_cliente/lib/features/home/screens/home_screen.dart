import 'package:flutter/material.dart';
import 'package:fixo/features/emergencias/screens/inicio_screen.dart';
import 'package:fixo/features/home/widgets/home_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      drawer: const HomeDrawer(),
      body: InicioScreen(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
    );
  }
}
