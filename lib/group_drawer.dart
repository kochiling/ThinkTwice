import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GroupDrawer extends StatelessWidget {
  final String groupName;
  final String groupCode;
  final String startDate;
  final String endDate;
  final String homeCurrency;
  final int memberCount;
  final VoidCallback onAddMember;
  final VoidCallback onChangeGroupName;
  final VoidCallback onExitGroup;

  const GroupDrawer({
    Key? key,
    required this.groupName,
    required this.groupCode,
    required this.startDate,
    required this.endDate,
    required this.homeCurrency,
    required this.memberCount,
    required this.onAddMember,
    required this.onChangeGroupName,
    required this.onExitGroup,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFFFFFF),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Color(0xFFF4D0F2)),
                  child: Text(
                    'Group Info',
                    style: TextStyle(fontSize: 24, color: Colors.black),
                  ),
                ),
                ListTile(
                  title: const Text("Group Name"),
                  subtitle: Text(groupName),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFFEC98E8)),
                    onPressed: onChangeGroupName,
                  ),
                ),
                ListTile(
                  title: const Text("Group Code"),
                  subtitle: Text(groupCode),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: groupCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Group code copied")),
                      );
                    },
                  ),
                ),
                ListTile(
                  title: const Text("Start Date"),
                  subtitle: Text(startDate),
                ),
                ListTile(
                  title: const Text("End Date"),
                  subtitle: Text(endDate),
                ),
                ListTile(
                  title: const Text("Home Currency"),
                  subtitle: Text(homeCurrency),
                ),
                ListTile(
                  title: const Text("Members"),
                  subtitle: Text("$memberCount members"),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_add, color: Color(0xFFEC98E8)),
                    onPressed: onAddMember,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                label: const Text('Exit Group', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: onExitGroup,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
