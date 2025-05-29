import 'package:flutter/material.dart';
import 'package:thinktwice/group_model.dart';

class GroupCard extends StatelessWidget{
  final GroupModel groupModel;
  final Function(String, bool) update;
  const GroupCard ({Key? key, required this.groupModel,
    required this.update,
  }): super (key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      color: Color(0xfffbe5ec),
      margin: const EdgeInsets.only(top: 1, bottom: 1),
      elevation: 4,
      child: ListTile(
        title: Text(groupModel.groupName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20,color: Color(0xFFc96077),)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text("Travel Date: ${groupModel.startDate} - ${groupModel.endDate}",),
            Text("Members: ${groupModel.memberCount}"),
          ],
        ),
        //trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // handle tap
        },
      ),
    );
  }

}