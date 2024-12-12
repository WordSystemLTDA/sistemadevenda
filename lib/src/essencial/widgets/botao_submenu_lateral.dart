// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';

class BotaoSubmenuLateral extends StatelessWidget {
  final double? padding;
  final double? altura;
  final Function() onTap;
  final Widget child;

  const BotaoSubmenuLateral({
    super.key,
    this.padding,
    this.altura,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: altura ?? 35,
      child: InkWell(
        onTap: () {
          onTap();
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: padding ?? 38.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
