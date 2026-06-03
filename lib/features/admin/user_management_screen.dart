import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/user_repository.dart';
import '../auth/auth_controller.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'user';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (currentUser?.isAdmin != true) {
      return Scaffold(
        appBar: _appBar(context),
        body: const Center(
          child: _StateCard(
            icon: Icons.lock_outline,
            title: 'Yönetici yetkisi gerekli',
            message: 'Giriş yetkisi yok.',
          ),
        ),
      );
    }

    final usersState = ref.watch(usersProvider);

    return Scaffold(
      appBar: _appBar(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AddUserCard(
                    nameController: _nameController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    role: _role,
                    saving: _saving,
                    onRoleChanged: (value) {
                      if (value != null) {
                        setState(() => _role = value);
                      }
                    },
                    onSave: _createUser,
                  ),
                  const SizedBox(height: 16),
                  usersState.when(
                    loading: () => const _StateCard(
                      icon: Icons.hourglass_empty,
                      title: 'Kullanıcılar yükleniyor',
                      message: 'Liste hazırlanıyor.',
                    ),
                    error: (_, __) => const _StateCard(
                      icon: Icons.error_outline,
                      title: 'Kullanıcılar alınamadı',
                      message: 'Tekrar deneyin.',
                    ),
                    data: (users) => _UserListCard(
                      users: users,
                      currentUser: currentUser!,
                      onRoleChanged: _setRole,
                      onActiveChanged: _setActive,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context) {
    return AppBar(
      title: const Text('Kullanıcı Yönetimi'),
      leading: IconButton(
        tooltip: 'Geri',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
            return;
          }
          context.go('/overview');
        },
      ),
    );
  }

  Future<void> _createUser() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      _showSnack('İsim yazmalısın.');
      return;
    }
    if (!email.contains('@')) {
      _showSnack('Geçerli bir e-posta yazmalısın.');
      return;
    }
    if (password.length < 6) {
      _showSnack('Geçici şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).createUser(
            email: email,
            password: password,
            displayName: name,
            role: _role,
          );
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() => _role = 'user');
      _showSnack('Kullanıcı eklendi.');
    } on FirebaseAuthException catch (error) {
      _showSnack(_authErrorMessage(error));
    } catch (_) {
      _showSnack('Kullanıcı eklenemedi.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _setRole(AppUser user, String role) async {
    final currentUser = ref.read(currentAppUserProvider).valueOrNull;
    if (currentUser?.uid == user.uid && role != 'admin') {
      _showSnack('Kendi yönetici yetkini kaldıramazsın.');
      return;
    }
    await ref.read(userRepositoryProvider).setUserRole(user: user, role: role);
    _showSnack('Yetki güncellendi.');
  }

  Future<void> _setActive(AppUser user, bool active) async {
    final currentUser = ref.read(currentAppUserProvider).valueOrNull;
    if (currentUser?.uid == user.uid && !active) {
      _showSnack('Kendi kullanıcını pasife alamazsın.');
      return;
    }
    await ref
        .read(userRepositoryProvider)
        .setUserActive(user: user, active: active);
    _showSnack(active ? 'Kullanıcı aktif edildi.' : 'Kullanıcı pasife alındı.');
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Bu e-posta zaten kayıtlı.';
      case 'invalid-email':
        return 'E-posta adresi geçerli değil.';
      case 'weak-password':
        return 'Şifre daha güçlü olmalı.';
      default:
        return 'Kullanıcı eklenemedi: ${error.message ?? error.code}';
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AddUserCard extends StatelessWidget {
  const _AddUserCard({
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.role,
    required this.saving,
    required this.onRoleChanged,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String role;
  final bool saving;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni Kullanıcı', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Ad Soyad'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Geçici Şifre'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: role,
            decoration: const InputDecoration(labelText: 'Yetki'),
            items: const [
              DropdownMenuItem(value: 'user', child: Text('Kullanıcı')),
              DropdownMenuItem(value: 'admin', child: Text('Yönetici')),
            ],
            onChanged: onRoleChanged,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_outlined),
            label: Text(saving ? 'Ekleniyor' : 'Kullanıcı Ekle'),
          ),
        ],
      ),
    );
  }
}

class _UserListCard extends StatelessWidget {
  const _UserListCard({
    required this.users,
    required this.currentUser,
    required this.onRoleChanged,
    required this.onActiveChanged,
  });

  final List<AppUser> users;
  final AppUser currentUser;
  final Future<void> Function(AppUser user, String role) onRoleChanged;
  final Future<void> Function(AppUser user, bool active) onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kullanıcılar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (users.isEmpty)
            const Text(
              'Henüz kullanıcı yok.',
              style: TextStyle(color: AppColors.mutedText),
            )
          else
            for (var index = 0; index < users.length; index++) ...[
              _UserTile(
                user: users[index],
                currentUser: currentUser,
                onRoleChanged: (role) => onRoleChanged(users[index], role),
                onActiveChanged: (active) =>
                    onActiveChanged(users[index], active),
              ),
              if (index != users.length - 1)
                const Divider(color: AppColors.border),
            ],
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.currentUser,
    required this.onRoleChanged,
    required this.onActiveChanged,
  });

  final AppUser user;
  final AppUser currentUser;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final isCurrent = user.uid == currentUser.uid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 620;
          final nameBlock = Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (user.isAdmin ? AppColors.bank : AppColors.primary)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  user.isAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_outline,
                  color: user.isAdmin ? AppColors.bank : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isEmpty
                          ? 'İsimsiz kullanıcı'
                          : user.displayName,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 3),
                      const Text(
                        'Bu sensin',
                        style:
                            TextStyle(color: AppColors.warning, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final controls = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: user.isAdmin ? 'admin' : 'user',
                  decoration: const InputDecoration(labelText: 'Yetki'),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('Kullanıcı')),
                    DropdownMenuItem(value: 'admin', child: Text('Yönetici')),
                  ],
                  onChanged: isCurrent
                      ? null
                      : (value) {
                          if (value != null) {
                            onRoleChanged(value);
                          }
                        },
                ),
              ),
              FilterChip(
                selected: user.active,
                label: Text(user.active ? 'Aktif' : 'Pasif'),
                avatar: Icon(
                  user.active ? Icons.check_circle_outline : Icons.block,
                  size: 18,
                ),
                onSelected: isCurrent
                    ? null
                    : (selected) {
                        onActiveChanged(selected);
                      },
              ),
            ],
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: nameBlock),
                const SizedBox(width: 12),
                controls,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              nameBlock,
              const SizedBox(height: 12),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 34),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}
