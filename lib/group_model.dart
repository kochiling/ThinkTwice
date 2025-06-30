class GroupModel {
  final String id;
  final String groupName;
  final String startDate;
  final String endDate;
  final Map<String, dynamic> members;
  final String groupCode;
  final String homeCurrency;
  final int memberCount;
  final String groupId;
  final Map<String, dynamic> memberArchive;

  GroupModel({
    required this.id,
    required this.groupName,
    required this.startDate,
    required this.endDate,
    required this.members,
    required this.groupCode,
    required this.homeCurrency,
    required this.memberCount,
    required this.groupId,
    required this.memberArchive,
  });

  factory GroupModel.fromMap(Map<dynamic, dynamic> data, String id) {
    return GroupModel(
      id: id,
      groupName: data['groupName'] ?? '',
      // startDate: _parseDate(data['startDate']),
      // endDate: _parseDate(data['endDate']),
      startDate: data['startDate'] ??'',
      endDate: data['endDate'] ??'',
      members: Map<String, dynamic>.from(data['members'] ?? {}),
      groupCode: data['groupCode'] ?? '',
      homeCurrency: data['homeCurrency'] ?? '',
      memberCount: data['memberCount'] ?? 0,
      groupId: data['groupId'] ?? '',
      memberArchive: Map<String, dynamic>.from(data ['memberArchive'] ?? {}),
    );
  }

// // helper to parse "dd-MM-yyyy"
//   static DateTime _parseDate(String? dateStr) {
//     if (dateStr == null) return DateTime.now();
//     try {
//       final parts = dateStr.split("-");
//       return DateTime(
//         int.parse(parts[2]),
//         int.parse(parts[1]),
//         int.parse(parts[0]),
//       );
//     } catch (_) {
//       return DateTime.now();
//     }
//   }
//
//   // Format date as "dd/MM/yyyy"
//   String formatDateOnly(String? dateStr) {
//     final date = _parseDate(dateStr);
//     return "${date.day.toString().padLeft(2, '0')}/"
//         "${date.month.toString().padLeft(2, '0')}/"
//         "${date.year}";
//   }

}
