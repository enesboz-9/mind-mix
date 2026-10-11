import 'package:flutter/material.dart';

import 'l10n.dart';

/// Ana menüde görünen bir mini oyunun tanımı.
class MiniGame {
  const MiniGame({
    required this.id,
    required this.nameEn,
    required this.nameTr,
    required this.descEn,
    required this.descTr,
    required this.icon,
    required this.color,
    required this.builder,
  });

  final String id;
  final String nameEn;
  final String nameTr;
  final String descEn;
  final String descTr;
  final IconData icon;
  final Color color;
  final Widget Function() builder;

  String name(AppStrings t) => t.isTr ? nameTr : nameEn;
  String desc(AppStrings t) => t.isTr ? descTr : descEn;
}
