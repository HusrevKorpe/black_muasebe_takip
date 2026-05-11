import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/employee.dart';
import '../providers/employee_providers.dart';
import 'employee_detail_sheet.dart';
import 'employee_form_sheet.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({
    super.key,
    required this.shopId,
    this.canEdit = true,
  });

  final String shopId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesProvider(shopId));

    return Scaffold(
      appBar: AppBar(title: const Text('Personeller')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => EmployeeFormSheet.show(context, shopId: shopId),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Personel Ekle'),
            )
          : null,
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Personeller yüklenemedi: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (employees) {
          if (employees.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  canEdit
                      ? 'Henüz personel eklenmedi.\nSağ alttaki butonla ekleyebilirsin.'
                      : 'Bu dükkan için kayıtlı personel yok.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: employees.length,
            itemBuilder: (context, i) {
              final e = employees[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EmployeeCard(
                  employee: e,
                  initials: _initials(e.name),
                  canEdit: canEdit,
                  onTap: () => EmployeeDetailSheet.show(
                    context,
                    employee: e,
                    canEdit: canEdit,
                  ),
                  onDelete: canEdit ? () => _confirmDelete(context, ref, e) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Employee e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Personeli sil'),
        content: Text('${e.name} silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(employeeRepositoryProvider)
          .delete(shopId: shopId, employeeId: e.id);
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinemedi: $err')),
        );
      }
    }
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.initials,
    required this.canEdit,
    required this.onTap,
    required this.onDelete,
  });

  final Employee employee;
  final String initials;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPartner = employee.isPartner;

    final avatarColors = isPartner
        ? [scheme.tertiary, scheme.primary]
        : [scheme.primary, scheme.secondary];

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.06),
                scheme.surface,
              ),
            ],
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: avatarColors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: avatarColors.first.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              employee.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: scheme.onSurface,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (isPartner) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Ortak',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      _InfoLine(
                        icon: Icons.phone_rounded,
                        text: employee.phone.isEmpty ? '—' : employee.phone,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 2),
                      _InfoLine(
                        icon: Icons.event_rounded,
                        text:
                            'Başlangıç: ${DateFormat('d MMM yyyy', 'tr_TR').format(employee.startDate)}',
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (canEdit && onDelete != null) ...[
                      _CirclePill(
                        icon: Icons.delete_outline_rounded,
                        iconSize: 16,
                        iconColor: scheme.error,
                        background: scheme.error.withValues(alpha: 0.10),
                        tooltip: 'Personeli sil',
                        onTap: onDelete,
                      ),
                      const SizedBox(height: 8),
                    ],
                    _CirclePill(
                      icon: Icons.arrow_forward_ios_rounded,
                      iconSize: 14,
                      iconColor: scheme.primary,
                      background: scheme.primary.withValues(alpha: 0.10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CirclePill extends StatelessWidget {
  const _CirclePill({
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.background,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final Color background;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: iconColor),
    );
    if (onTap == null) return pill;
    final tappable = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: pill),
    );
    return tooltip != null
        ? Tooltip(message: tooltip!, child: tappable)
        : tappable;
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
