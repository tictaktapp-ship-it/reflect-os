import 'package:flutter/material.dart';
import 'package:reflect_os/widgets/reflect_logo.dart';

/// Standard auth-screen logo — large centred version of ReflectLogo.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: ReflectLogo(iconSize: 44));
  }
}
