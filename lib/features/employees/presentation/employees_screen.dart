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
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(_initials(e.name))),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (e.isPartner)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Ortak',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${e.phone}\nBaşlangıç: ${DateFormat('d MMM yyyy', 'tr_TR').format(e.startDate)}',
                    ),
                    isThreeLine: true,
                    onTap: () => EmployeeDetailSheet.show(
                      context,
                      employee: e,
                      canEdit: canEdit,
                    ),
                    trailing: canEdit
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: 'Personeli sil',
                            onPressed: () => _confirmDelete(context, ref, e),
                          )
                        : null,
                  ),
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
