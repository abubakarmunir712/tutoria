import 'package:flutter/material.dart';

import '../tokens.dart';

class TNavItem {
  const TNavItem(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// The bottom navigation bar: white, softly lifted, the selected tab in brand blue.
class TNavBar extends StatelessWidget {
  const TNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<TNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(TRadius.xl)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0245B0),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(TRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            i == index ? items[i].activeIcon : items[i].icon,
                            color: i == index ? TColors.blue600 : TColors.faint,
                            size: 26,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].label,
                            style: TText.caption.copyWith(
                              color: i == index
                                  ? TColors.blue600
                                  : TColors.faint,
                              fontWeight: i == index
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
