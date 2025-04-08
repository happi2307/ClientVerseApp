import 'package:flutter/material.dart';
import 'package:flutter_application_1/constants/app_colors.dart';
import 'package:flutter_application_1/screens/ai_chat/ai_chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/providers/app_state_provider.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    
    return BottomNavigationBar(
      currentIndex: appState.currentIndex,
      onTap: (index) {
        // If AI Chat button is tapped (index 2), navigate to chat screen
        if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AiChatScreen()),
          );
        } else {
          appState.setCurrentIndex(index);
        }
      },
      backgroundColor: AppColors.cardBackground,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.menu),
          label: 'Menu',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'AI Chat',
        ),
      ],
    );
  }
}