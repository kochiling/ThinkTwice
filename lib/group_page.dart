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
  String _searchKeyword = '';
  TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  bool _showArchived = false;

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
            // Always add if user is a member, regardless of archive status
            if (members != null && members[userId] == true) {
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
    final userId = _auth.currentUser?.uid;
    final filteredGroups = userGroups.where((group) {
      final memberArchive = group.memberArchive;
      final name = group.groupName.toLowerCase();
      final code = (group.groupCode ?? '').toLowerCase();
      final matchesSearch = _searchKeyword.isEmpty || name.contains(_searchKeyword.toLowerCase()) || code.contains(_searchKeyword.toLowerCase());
      if (_showArchived) {
        return matchesSearch && memberArchive != null && memberArchive[userId] == true;
      } else {
        return matchesSearch && (memberArchive == null || memberArchive[userId] != true);
      }
    }).toList();
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search groups...',
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchKeyword = val.trim();
                    });
                  },
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(_showArchived ? 'Archived Groups' : 'Groups'),
                    ),
                  ],
                ),
          actions: [
            if (!_showSearch)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearch = true;
                  });
                },
              ),
            if (!_showSearch)
              IconButton(
                icon: Icon(_showArchived ? Icons.unarchive : Icons.archive),
                tooltip: _showArchived ? 'Show Active Groups' : 'Show Archived Groups',
                onPressed: () {
                  setState(() {
                    _showArchived = !_showArchived;
                  });
                },
              ),
            if (_showSearch)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showSearch = false;
                    _searchKeyword = '';
                    _searchController.clear();
                  });
                },
              ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredGroups.isEmpty
            ? Center(child: Text(_showArchived ? "No archived groups." : "No groups found."))
            : ListView.builder(
          padding: const EdgeInsets.only(top: 1, bottom: 1, right: 2, left: 2),
          itemCount: filteredGroups.length,
          itemBuilder: (context, index) {
            final group = filteredGroups[index];
            return Dismissible(
              key: Key(group.groupId + (_showArchived ? '_archived' : '')),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                color: _showArchived ? Colors.green : Colors.orangeAccent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(_showArchived ? Icons.unarchive : Icons.archive, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(_showArchived ? 'Unarchive' : 'Archive', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(_showArchived ? 'Unarchive Group' : 'Archive Group'),
                    content: Text(_showArchived
                        ? 'Do you want to unarchive "${group.groupName}"?'
                        : 'Are you sure you want to archive "${group.groupName}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(_showArchived ? 'Unarchive' : 'Archive'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) async {
                final userId = _auth.currentUser?.uid;
                if (userId != null) {
                  if (_showArchived) {
                    // Unarchive
                    await _dbRef.child(group.groupId).child('memberArchive').child(userId).remove();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Group "${group.groupName}" unarchived.')),
                    );
                  } else {
                    // Archive
                    await _dbRef.child(group.groupId).child('memberArchive').update({userId: true});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Group "${group.groupName}" archived.'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () async {
                            await _dbRef.child(group.groupId).child('memberArchive').child(userId).remove();
                            _fetchUserGroups();
                          },
                        ),
                      ),
                    );
                  }
                  _fetchUserGroups();
                }
              },
              child: GroupCard(
                groupModel: group,
                update: (id, updated) {},
                highlight: _searchKeyword,
              ),
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