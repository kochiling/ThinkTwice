import 'package:flutter/material.dart';
import 'package:thinktwice/group_model.dart';
import 'package:thinktwice/group_detail_page.dart';

class GroupCard extends StatelessWidget{
  final GroupModel groupModel;
  final Function(String, bool) update;
  final String? highlight;
  const GroupCard ({Key? key, required this.groupModel,
    required this.update,
    this.highlight,
  }): super (key: key);

  Widget _highlightedText(String text, TextStyle style) {
    if (highlight == null || highlight!.isEmpty) return Text(text, style: style);
    final lower = text.toLowerCase();
    final lowerHighlight = highlight!.toLowerCase();
    final start = lower.indexOf(lowerHighlight);
    if (start < 0) return Text(text, style: style);
    final end = start + highlight!.length;
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(text: text.substring(start, end), style: style.copyWith(backgroundColor: Colors.yellow)),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      color: Color(0xfffbe5ec),
      margin: const EdgeInsets.only(top: 1, bottom: 1),
      elevation: 4,
      child: ListTile(
        title: _highlightedText(
          groupModel.groupName,
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFc96077)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text("Travel Date: "+groupModel.startDate+" - "+groupModel.endDate),
            Text("Members: "+groupModel.memberCount.toString()),
          ],
        ),
        //trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailsPage(
                groupId: groupModel.id,
                homeCurrency: groupModel.homeCurrency,
              ),
            ),
          );
        },
      ),
    );
  }

}