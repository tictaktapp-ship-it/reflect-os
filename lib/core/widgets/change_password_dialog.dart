import 'package:flutter/material.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opens the branded Change Password dialog centred on screen.
Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;

  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    String? newErr;
    String? confirmErr;

    final pw = _newController.text;
    if (pw.length < 8) {
      newErr = 'Password must be at least 8 characters';
    } else if (!RegExp(r'[A-Z]').hasMatch(pw)) {
      newErr = 'Must contain at least one uppercase letter';
    } else if (!RegExp(r'[0-9]').hasMatch(pw)) {
      newErr = 'Must contain at least one number';
    } else if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};\':"\\|,.<>\/?]')
        .hasMatch(pw)) {
      newErr = 'Must contain at least one special character';
    }

    if (_confirmController.text != pw) {
      confirmErr = 'Passwords do not match';
    }

    setState(() {
      _newError = newErr;
      _confirmError = confirmErr;
    });
    return newErr == null && confirmErr == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _newController.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogShell(
      title: 'Change Password',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // New password
          TextField(
            controller: _newController,
            obscureText: !_showNew,
            onChanged: (_) {
              if (_newError != null) setState(() => _newError = null);
            },
            decoration: InputDecoration(
              labelText: 'New password',
              errorText: _newError,
              suffixIcon: IconButton(
                icon: Icon(
                  _showNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _showNew = !_showNew),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Confirm password
          TextField(
            controller: _confirmController,
            obscureText: !_showConfirm,
            onChanged: (_) {
              if (_confirmError != null) setState(() => _confirmError = null);
            },
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              errorText: _confirmError,
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF19CBD6),
            ),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Change password'),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
