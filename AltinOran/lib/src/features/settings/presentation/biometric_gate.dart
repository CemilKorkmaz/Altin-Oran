import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate> {
  bool _authInProgress = false;
  bool _unlocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryAuth();
  }

  Future<void> _tryAuth() async {
    setState(() {
      _authInProgress = true;
      _error = null;
    });

    final localAuth = LocalAuthentication();
    try {
      final canCheck = await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();
      if (!canCheck) {
        setState(() {
          _unlocked = true;
          _authInProgress = false;
        });
        return;
      }

      final didAuth = await localAuth.authenticate(
        localizedReason: 'Portföyünü görmek için kimliğini doğrula',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );

      if (didAuth) {
        setState(() {
          _unlocked = true;
          _authInProgress = false;
        });
      } else {
        setState(() {
          _authInProgress = false;
          _error = 'Kimlik doğrulama iptal edildi.';
        });
      }
    } catch (e) {
      setState(() {
        _authInProgress = false;
        _error = 'Kimlik doğrulama başarısız: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Portföy kilitli',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ??
                      'Birikimler ekranına erişmek için parmak izi, Face ID veya cihaz şifrenle giriş yap.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (_authInProgress)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: _tryAuth,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Tekrar dene'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

