import 'package:flutter/material.dart';

/// Badges showing price context (sale, member price, coupon, bulk discount)
class PriceContextBadges extends StatelessWidget {
  final bool? isSaleVisible;
  final bool? isMemberPriceVisible;
  final bool? isCouponPriceVisible;
  final bool? isBulkDiscount;

  const PriceContextBadges({
    super.key,
    this.isSaleVisible,
    this.isMemberPriceVisible,
    this.isCouponPriceVisible,
    this.isBulkDiscount,
  });

  @override
  Widget build(BuildContext context) {
    final badges = <_BadgeData>[];

    if (isSaleVisible == true) {
      badges.add(
        _BadgeData(label: 'SALE', icon: Icons.local_offer, color: Colors.red),
      );
    }
    if (isMemberPriceVisible == true) {
      badges.add(
        _BadgeData(
          label: '会員価格',
          icon: Icons.card_membership,
          color: Colors.blue,
        ),
      );
    }
    if (isCouponPriceVisible == true) {
      badges.add(
        _BadgeData(
          label: 'クーポン',
          icon: Icons.confirmation_number,
          color: Colors.orange,
        ),
      );
    }
    if (isBulkDiscount == true) {
      badges.add(
        _BadgeData(
          label: 'まとめ割',
          icon: Icons.inventory_2,
          color: Colors.purple,
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: badges.map((b) => _Badge(data: b)).toList(),
    );
  }
}

class _BadgeData {
  final String label;
  final IconData icon;
  final Color color;

  const _BadgeData({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _Badge extends StatelessWidget {
  final _BadgeData data;

  const _Badge({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 14, color: data.color),
          const SizedBox(width: 4),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: data.color,
            ),
          ),
        ],
      ),
    );
  }
}
