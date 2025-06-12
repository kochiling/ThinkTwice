import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:thinktwice/create_group.dart';
import 'package:thinktwice/group_model.dart';
import 'package:thinktwice/group_card.dart';


class GroupPage extends StatefulWidget{

  const GroupPage ({Key? key}): super (key: key);

  @override
  State<GroupPage> createState() => _GroupPageState();

}

class _GroupPageState extends State <GroupPage>{

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("Groups");
  List<GroupModel> userGroups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserGroups();
  }

  Future<void> _fetchUserGroups() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print("User not logged in.");
      return;
    }

    final userId = currentUser.uid;
    print("Current User ID: $userId");

    try {
      final snapshot = await _dbRef.get();

      List<GroupModel> groups = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        print("Fetched group data: $data");

        data.forEach((groupId, groupData) {
          if (groupData is Map<dynamic, dynamic>) {
            final members = groupData['members'] as Map<dynamic, dynamic>?;
            print("Group $groupId members: $members");
            print("User $userId is a member of group $groupId");

            if (groupData['members'] != null &&
                groupData['members'][userId] == true) {
              final group = GroupModel.fromMap(groupData, groupId);
              groups.add(group);
            }
          }
        });
      }

      setState(() {
        userGroups = groups;
        isLoading = false;
      });

      print("Total groups for user: ${groups.length}");
    } catch (e) {
      print("Error fetching groups: $e");
    }
  }


  void _showGroupOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateGroup(),
                    ),
                  );
                  print("Create group clicked");
                },
                icon: const Icon(Icons.group_add),
                label: const Text("Create Group"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _joinGroup();
                  print("Join group clicked");
                },
                icon: const Icon(Icons.group),
                label: const Text("Join Group"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _joinGroup() {
    final TextEditingController groupCodeText = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Join Group"),
        content: TextField(
          controller: groupCodeText,
          decoration: const InputDecoration(
            labelText: "Enter group code to join",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final groupCode = groupCodeText.text.trim();
              if (groupCode.isEmpty) {
                // Show error or just return
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a group code.")),
                );
                return;
              }

              Navigator.of(context).pop(); // Close the dialog first

              final currentUser = _auth.currentUser;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User not logged in.")),
                );
                return;
              }
              final userId = currentUser.uid;

              try {
                // Search groups where groupCode == entered code
                final groupsSnapshot = await _dbRef
                    .orderByChild('groupCode')
                    .equalTo(groupCode)
                    .get();

                if (!groupsSnapshot.exists) {
                  // No group with that code
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Group Not Found"),
                      content: Text("No group found with code '$groupCode'."),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"))
                      ],
                    ),
                  );
                  return;
                }

                // There could be multiple groups, but usually one
                final data = groupsSnapshot.value as Map<dynamic, dynamic>;

                // Just get the first group matching the code
                final groupId = data.keys.first;
                final groupData = data[groupId];

                final members = groupData['members'] as Map<dynamic, dynamic>? ?? {};
                final memberCount = groupData['memberCount'] ?? 0;
                final groupName = groupData['groupName'] ?? "Unnamed Group";

                if (members.containsKey(userId) && members[userId] == true) {
                  // User already in group
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Already Joined"),
                      content: Text("You have already joined the group '$groupName'."),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("OK"))
                      ],
                    ),
                  );
                  return;
                }

                // Show confirmation dialog with group info
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("Join Group: $groupName"),
                    content: Text("Members: $memberCount\nDo you want to join this group?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop(); // close confirm dialog

                          // Add user to members with true, increment memberCount
                          await _dbRef.child(groupId).update({
                            "members/$userId": true,
                            "memberCount": memberCount + 1,
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Joined group '$groupName' successfully.")),
                          );

                          // Refresh groups list if needed
                          _fetchUserGroups();
                        },
                        child: const Text("Join"),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                // Handle any errors
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Error"),
                    content: Text("An error occurred: $e"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("OK"))
                    ],
                  ),
                );
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }



  Widget build (BuildContext context){
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Groups'),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : userGroups.isEmpty
            ? const Center(child: Text("You are not in any groups."))
            : ListView.builder(
          padding: const EdgeInsets.only(top: 1, bottom: 1, right: 2, left: 2),
          itemCount: userGroups.length,
          itemBuilder: (context, index) {
            final group = userGroups[index];
            return GroupCard(
              groupModel: group,
              update: (id, updated) {},
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: (){_showGroupOptionsSheet();},
            child: const Icon(
                Icons.add
            )
        ),
      ),
    );
  }
}