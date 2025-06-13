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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFDE2E4),
      child: ListView(
        //padding: const EdgeInsets.all(16.0),
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFFCDB4DB)),
            child: Text(
              'Group Info',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
          ListTile(
            title: const Text("Group Name"),
            subtitle: Text(groupName),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF9D4EDD)),
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
              icon: const Icon(Icons.person_add, color: Color(0xFF9D4EDD)),
              onPressed: onAddMember,
            ),
          ),
        ],
      ),
    );
  }
}
