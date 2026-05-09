import 'package:flutter/material.dart';
import '../../../shared/widgets/custom_card.dart';

class ReflectionBottomSheet extends StatelessWidget {
  final String sessionId;
  final String promptType;
  final int driftScore;
  final Function(String) onResponse;

  const ReflectionBottomSheet({
    super.key,
    required this.sessionId,
    required this.promptType,
    required this.driftScore,
    required this.onResponse,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDeep = promptType == "DEEP";
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isDeep ? "DEEP REFLECTION" : "MILD REFLECTION",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDeep ? Colors.orangeAccent : Colors.blueAccent,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isDeep 
              ? "Did you find what you opened the app for?"
              : "Was this session intentional?",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          _buildOptions(context, isDeep),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptions(BuildContext context, bool isDeep) {
    final List<String> options = isDeep 
        ? ["Yes", "Forgot Midway", "No"]
        : ["Yes", "Mostly", "Not Really"];

    return Column(
      children: options.map((opt) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => onResponse(opt),
          child: CustomCard(
            useGlass: true,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            borderRadius: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  opt,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }
}
